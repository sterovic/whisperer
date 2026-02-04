class YouTubeVideoImportJob < ApplicationJob
  queue_as :default

  def perform(user_id, project_id, urls_text, options = {})
    @user = User.find(user_id)
    @project = Project.find(project_id)
    @job_id = provider_job_id || job_id
    @import_existing_comments = options[:import_existing_comments] || false
    @imported_comments_count = 0

    urls = parse_urls(urls_text)
    @total_steps = urls.size + 1 # +1 for initialization step
    @current_step = 0

    begin
      broadcast_progress("Parsing #{urls.size} video URL(s)...")
      @current_step = 1

      urls.each_with_index do |url, index|
        youtube_id = Video.extract_youtube_id(url)

        if youtube_id.nil?
          broadcast_progress("Skipping invalid URL: #{url.truncate(50)}")
          next
        end

        @current_step = index + 2
        broadcast_progress("Fetching video #{index + 1}/#{urls.size}: #{youtube_id}")

        video = fetch_and_store_video(youtube_id, url)
        broadcast_progress("Video already exists, data will be updated") unless video.previously_new_record?

        if video && @import_existing_comments
          broadcast_progress("Scanning comments for #{@project.name}...")
          import_existing_comments(video)
        end
      end

      message = "Successfully imported #{urls.size} video(s)"
      message += " and #{@imported_comments_count} comment(s)" if @imported_comments_count > 0
      broadcast_completion(success: true, message: message)

    rescue StandardError => e
      Rails.logger.error "YouTubeVideoImportJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      broadcast_error(e.message)
      raise
    end
  end

  private

  def parse_urls(urls_text)
    urls_text
      .split(/[\n\r]+/)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  def import_existing_comments(video)
    return unless video

    yt_video = Yt::Video.new(id: video.youtube_id)
    product_name = @project.name

    existing_youtube_ids = video.comments.pluck(:youtube_comment_id).compact
    rank = 0
    video_imported_count = 0

    # Fetch comment threads ordered by relevance
    yt_video.comment_threads.where(order: :time).each do |thread|
      text = thread.text_display
      next unless text_contains_product_name?(text, product_name)
      next if existing_youtube_ids.include?(thread.id)

      Comment.create!(
        video: video,
        project: @project,
        youtube_comment_id: thread.id,
        text: text,
        author_display_name: thread.author_display_name,
        author_avatar_url: thread.author_profile_image_url,
        like_count: thread.like_count || 0,
        status: :visible,
        post_type: :manual
      )

      video_imported_count += 1
      @imported_comments_count += 1
      existing_youtube_ids << thread.id
    end

    broadcast_progress("Found #{video_imported_count} comment(s) mentioning #{@project.name}") if video_imported_count > 0
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Comments disabled for video #{video.youtube_id}: #{e.message}"
    broadcast_progress("Comments disabled on this video")
  rescue Yt::Errors::RequestError => e
    Rails.logger.warn "Error fetching comments for video #{video.youtube_id}: #{e.message}"
    broadcast_progress("Could not fetch comments: #{e.message.truncate(50)}")
  end

  def fetch_and_store_video(youtube_id, original_url)
    yt_video = Yt::Video.new(id: youtube_id)

    video = @project.videos.find_or_initialize_by(youtube_id: youtube_id)
    video.assign_attributes(
      title: yt_video.title,
      description: yt_video.description,
      like_count: yt_video.like_count || 0,
      comment_count: yt_video.comment_count || 0,
      view_count: yt_video.view_count || 0,
      thumbnail_url: extract_thumbnail_url(yt_video),
      fetched_at: Time.current,
      raw_data: build_raw_data(yt_video, original_url)
    )
    video.save!

    video
  rescue Yt::Errors::NoItems => e
    Rails.logger.warn "Video not found: #{youtube_id}"
    broadcast_progress("Video not found or unavailable: #{youtube_id}")
    nil
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Access forbidden for video: #{youtube_id}"
    broadcast_progress("Access denied for video: #{youtube_id}")
    nil
  rescue Yt::Errors::ServerError => e
    Rails.logger.error "Error fetching video: #{youtube_id}\n#{e.message}\n#{e.backtrace.join("\n")}"
    broadcast_progress("Error fetching video: #{youtube_id}")
    nil
  end

  def extract_thumbnail_url(yt_video)
    # Try to get the highest quality thumbnail available
    yt_video.thumbnail_url(:maxres) ||
      yt_video.thumbnail_url(:high) ||
      yt_video.thumbnail_url(:medium) ||
      yt_video.thumbnail_url(:default)
  rescue
    nil
  end

  def build_raw_data(yt_video, original_url)
    {
      original_url: original_url,
      channel_id: yt_video.channel_id,
      channel_title: yt_video.channel_title,
      published_at: yt_video.published_at&.iso8601,
      duration: yt_video.duration,
      view_count: yt_video.view_count,
      tags: yt_video.tags,
      category_id: yt_video.category_id,
      category_title: yt_video.category_title,
      live_broadcast_content: yt_video.live_broadcast_content
    }
  rescue => e
    { original_url: original_url, error: e.message }
  end

  def broadcast_progress(message)
    progress_percentage = (@current_step.to_f / @total_steps * 100).to_i

    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "YouTube Video Import",
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
        job_name: "YouTube Video Import",
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
        job_name: "YouTube Video Import",
        message: "Error: #{error_message}",
        percentage: 0,
        status: :failed
      }
    )
  end

  # Checks if text contains the product name, handling variations like:
  # - Different cases: "FAMESTER", "famester", "FaMeStEr"
  # - Dots between letters: "f.a.m.e.s.t.e.r"
  # - Spaces between letters: "F a M e S t E r"
  # - Other separators: "f-a-m-e-s-t-e-r", "f_a_m_e_s_t_e_r"
  def text_contains_product_name?(text, product_name)
    # Normalize by removing common separators and converting to lowercase
    normalized_text = normalize_for_matching(text)
    normalized_product = normalize_for_matching(product_name)

    normalized_text.include?(normalized_product)
  end

  def normalize_for_matching(str)
    # Remove dots, spaces, dashes, underscores and other common separators
    # Then downcase for case-insensitive matching
    str.gsub(/[\s.\-_*]+/, "").downcase
  end
end
