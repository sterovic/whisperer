class CommentPostingJob < ApplicationJob
  queue_as :default

  after_perform do |job|
    # Reschedule with same user/project if enabled
    schedule = JobSchedule.for(job.class.name)
    job.class.set(wait: schedule.interval_minutes.minutes).perform_later(*job.arguments) if schedule.enabled?
  end

  def perform(user_id, project_id)
    schedule = JobSchedule.for(self.class.name)

    # Skip if another instance already ran recently (prevents duplicates when interval changes)
    if schedule.recently_ran?
      Rails.logger.info "CommentPostingJob: Skipping - another instance ran recently"
      return
    end

    schedule.touch(:last_run_at)
    @user = User.find(user_id)
    @project = Project.find(project_id)
    @job_id = provider_job_id || job_id
    @google_accounts = @user.google_accounts.to_a

    if @google_accounts.empty?
      broadcast_error("No Google accounts linked. Please connect at least one account.")
      return
    end

    uncommented_videos = find_uncommented_videos
    @total_steps = uncommented_videos.size
    @current_step = 0

    if uncommented_videos.empty?
      broadcast_completion(success: true, message: "No uncommented videos found")
      return
    end

    begin
      broadcast_progress("Found #{uncommented_videos.size} video(s) to comment on...")

      uncommented_videos.each_with_index do |video, index|
        @current_step = index + 1
        broadcast_progress("Processing video #{index + 1}/#{uncommented_videos.size}: #{video.title&.truncate(40)}")

        post_comment_to_video(video)
        sleep 4
      end

      broadcast_completion(success: true, message: "Posted comments on #{uncommented_videos.size} video(s)")

    rescue StandardError => e
      Rails.logger.error "CommentPostingJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      broadcast_error(e.message)
      raise
    end
  end

  private

  def find_uncommented_videos
    commented_video_ids = @project.comments.pluck(:video_id).uniq
    @project.videos.where.not(id: commented_video_ids)
  end

  def post_comment_to_video(video)
    google_account = @google_accounts.sample
    broadcast_progress("Generating comment for: #{video.title&.truncate(40)}")

    comment_text = generate_comment(video)
    if comment_text.blank?
      broadcast_progress("Could not generate comment, skipping...")
      return
    end

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
      status: :visible
    )

    broadcast_progress("Comment posted successfully!")
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Cannot post comment (forbidden): #{e.message}"
    broadcast_progress("Could not post comment: access denied")
  rescue Yt::Errors::RequestError => e
    Rails.logger.warn "Cannot post comment: #{e.message}"
    broadcast_progress("Could not post comment: #{e.message.truncate(50)}")
  end

  def generate_comment(video)
    yt_video = Yt::Video.new(id: video.youtube_id)
    existing_comments = yt_video.comment_threads.take(10).map(&:text_display)

    generator = CommentGenerator.new
    comments = generator.generate_comments(
      product_name: @project.name,
      product_description: @project.description.to_s,
      title: video.title,
      description: video.description,
      comments: existing_comments,
      num_comments: 1
    )
    comments.first
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
        step: @current_step,
        total_steps: @total_steps,
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
        step: @total_steps,
        total_steps: [@total_steps, 1].max,
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
        step: @current_step,
        total_steps: [@total_steps, 1].max,
        message: "Error: #{error_message}",
        percentage: 0,
        status: :failed
      }
    )
  end
end