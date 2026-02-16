class CommentPostingJob < ScheduledJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "#{self.class.name}-#{arguments.second}" }
  )

  self.job_display_name = "Comment Posting"

  private

  def execute(options)
    @skip_reschedule = options[:skip_reschedule]
    @video_ids = options[:video_ids]

    # Check comment posting method
    if @project.use_smm_panel?
      @smm_credential = @user.smm_panel_credentials.find_by(panel_type: @project.prompt_setting(:smm_panel_type))
      if @smm_credential.nil?
        Rails.logger.warn "CommentPostingJob: SMM Panel not configured for project #{@project.id}"
        broadcast_error("SMM Panel not configured. Please configure your SMM panel in settings.")
        return
      end
      if @smm_credential.comment_service_id.blank?
        Rails.logger.warn "CommentPostingJob: Comment service ID not set for project #{@project.id}"
        broadcast_error("Comment service ID not set for SMM panel. Please configure it in SMM Panels settings.")
        return
      end
    else
      @usable_accounts = @user.google_accounts.usable.to_a
      if @usable_accounts.empty?
        Rails.logger.warn "CommentPostingJob: No usable Google accounts for user #{@user.id} (total accounts: #{@user.google_accounts.count}, statuses: #{@user.google_accounts.pluck(:token_status).tally})"
        broadcast_error("No usable Google accounts. Please connect or reconnect an account.")
        return
      end
    end

    videos_to_process = find_videos_to_process
    @total_steps = videos_to_process.size
    @current_step = 0

    if videos_to_process.empty?
      broadcast_completion(success: true, message: "No videos to process")
      return
    end

    begin
      broadcast_progress("Found #{videos_to_process.size} video(s) to comment on...")

      videos_to_process.each_with_index do |video, index|
        @current_step = index + 1
        broadcast_progress("Processing video #{index + 1}/#{videos_to_process.size}: #{video.title&.truncate(40)}")

        post_comment_to_video(video)
        sleep 2
      end

      broadcast_completion(success: true, message: "Posted comments on #{videos_to_process.size} video(s)")

    rescue StandardError => e
      Rails.logger.error "CommentPostingJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      broadcast_error(e.message)
      raise
    end
  end

  def find_videos_to_process
    if @video_ids.present?
      # Manual trigger with specific videos - process these regardless of existing comments
      @project.videos.where(id: @video_ids)
    else
      # Automated run - only process uncommented videos
      commented_video_ids = @project.comments.select(:video_id).distinct
      @project.videos.where.not(id: commented_video_ids)
    end
  end

  def post_comment_to_video(video)
    broadcast_progress("Generating comment for: #{video.title&.truncate(40)}")
    uses_yt_api = @project.use_smm_panel? ? false : true

    comments = generate_comments(video, uses_yt_api ? 1 : @project.prompt_setting(:num_comments))
    if comments.blank?
      broadcast_progress("Could not generate comments, skipping...")
      return
    end

    if uses_yt_api
      post_comment_via_youtube_api(video, comments.first)
    else
      post_comment_via_smm_panel(video, comments)
    end
  end

  def post_comment_via_youtube_api(video, comment_text)
    google_account = @usable_accounts.sample
    broadcast_progress("Posting comment as #{google_account.display_name}...")

    yt_account = google_account.yt_account
    yt_response = yt_account.comment_threads.insert(
      video_id: video.youtube_id,
      text_original: comment_text
    )

    youtube_comment_id = yt_response.id rescue nil

    Comment.create!(
      text: comment_text,
      video: video,
      google_account: google_account,
      project: @project,
      youtube_comment_id: youtube_comment_id,
      status: :visible,
      author_display_name: yt_response.author_display_name,
      author_avatar_url: yt_response.author_profile_image_url,
      post_type: :via_api
    )

    broadcast_progress("Comment posted successfully!")
  rescue GoogleAccount::TokenNotUsableError => e
    Rails.logger.warn "Account token not usable: #{e.message}"
    broadcast_progress("Account #{google_account.display_name} token is not usable, skipping...")
    @usable_accounts.delete(google_account) # Remove from pool for this job run
  rescue Yt::Errors::Unauthorized => e
    Rails.logger.warn "Account unauthorized: #{e.message}"
    google_account.mark_as_unauthorized!
    @usable_accounts.delete(google_account) # Remove from pool for this job run
    broadcast_progress("Account #{google_account.display_name} authorization expired, marked as unauthorized")
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Cannot post comment (forbidden): #{e.message}"
    broadcast_progress("Could not post comment: access denied")
  rescue Yt::Errors::RequestError => e
    Rails.logger.warn "Cannot post comment: #{e.message}"
    broadcast_progress("Could not post comment: #{e.message.truncate(50)}")
  end

  def post_comment_via_smm_panel(video, comments)
    broadcast_progress("Posting comments via #{@smm_credential.display_name}...")

    video_url = "https://www.youtube.com/watch?v=#{video.youtube_id}"
    adapter = @smm_credential.adapter

    result = adapter.bulk_comment(
      video_url: video_url,
      comments: comments,
      service_id: @smm_credential.comment_service_id
    )

    if result[:success]
      # Create SMM order record
      order = SmmOrder.create!(
        smm_panel_credential: @smm_credential,
        project: @project,
        video: video,
        external_order_id: result[:order_id],
        service_type: :comment,
        status: :pending,
        quantity: comments.size,
        link: video_url
      )

      broadcast_progress("Comment order placed! Order ID: #{result[:order_id]}")
    else
      broadcast_progress("SMM Panel error: #{result[:error]}")
    end
  rescue SmmAdapters::BaseAdapter::ApiError => e
    Rails.logger.warn "SMM Panel error: #{e.message}"
    broadcast_progress("SMM Panel error: #{e.message.truncate(50)}")
  end

  def generate_comments(video, comment_count = 1)
    generator = CommentGenerator.new
    generator.generate_comments(
      project: @project,
      video: video,
      num_comments: comment_count
    )
  rescue => e
    Rails.logger.error "Error generating comment: #{e.message}"
    nil
  end

  def broadcast_progress(message)
    progress_percentage = @total_steps.positive? ? (@current_step.to_f / @total_steps * 100).to_i : 0

    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Comment Posting",
        message: message,
        percentage: progress_percentage,
        status: :running
      }
    )
  end

  def broadcast_completion(success:, message:)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Comment Posting",
        message: message,
        percentage: 100,
        status: success ? :completed : :failed
      }
    )
  end

  def broadcast_error(error_message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Comment Posting",
        message: "Error: #{error_message.truncate(200)}",
        percentage: 0,
        status: :failed
      }
    )
  end
end
