class RelatedVideoSearchJob < ApplicationJob
  queue_as :default

  def perform(user_id, project_id, options = {})
    options = options.symbolize_keys
    @user = User.find(user_id)
    @project = Project.find(project_id)
    @job_id = provider_job_id || job_id

    video_ids = options[:video_ids] || []
    max_results = (options[:max_results] || 10).to_i
    min_views = (options[:min_views] || 0).to_i
    min_comments = (options[:min_comments] || 0).to_i
    published_after = parse_published_after(options[:published_after])

    if video_ids.blank?
      broadcast_error("No source videos selected")
      return
    end

    api_key = Rails.application.credentials.dig(:serpapi, :api_key)
    if api_key.blank?
      broadcast_error("SerpApi API key not configured")
      return
    end

    source_videos = @project.videos.where(id: video_ids)
    if source_videos.empty?
      broadcast_error("No valid source videos found")
      return
    end

    @imported_count = 0
    @skipped_count = 0
    @seen_ids = Set.new

    begin
      broadcast_progress("Finding related videos for #{source_videos.size} source video(s)...", 5)

      source_videos.each_with_index do |source_video, source_index|
        break if @imported_count >= max_results

        source_percentage = ((source_index.to_f / source_videos.size) * 80).to_i + 10
        broadcast_progress("Fetching related videos for: #{source_video.title&.truncate(40)}", source_percentage)

        begin
          client = SerpApi::Client.new(
            engine: "youtube_video",
            api_key: api_key
          )
          result = client.search(v: source_video.youtube_id)
          related = result[:related_videos] || result["related_videos"] || []

          related.each do |related_video|
            break if @imported_count >= max_results

            youtube_id = extract_youtube_id_from_related(related_video)
            next if youtube_id.blank?
            next if @seen_ids.include?(youtube_id)
            @seen_ids.add(youtube_id)

            # Apply filters from related video data if available
            views = parse_view_count(related_video)
            if min_views > 0 && views < min_views
              @skipped_count += 1
              next
            end

            broadcast_progress("Importing: #{(related_video[:title] || related_video["title"])&.truncate(40)}", source_percentage + 5)
            import_video_by_id(youtube_id)
          end
        rescue => e
          Rails.logger.warn "SerpApi error for video #{source_video.youtube_id}: #{e.message}"
          broadcast_progress("Could not fetch related videos for: #{source_video.title&.truncate(30)}")
        end
      end

      message = "Imported #{@imported_count} related video(s)"
      message += ", skipped #{@skipped_count} (filtered/errors)" if @skipped_count > 0
      broadcast_completion(success: true, message: message)

    rescue StandardError => e
      Rails.logger.error "RelatedVideoSearchJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      broadcast_error(e.message)
      raise
    end
  end

  private

  def parse_published_after(value)
    case value
    when "last_hour" then 1.hour.ago
    when "today" then Time.current.beginning_of_day
    when "this_week" then 1.week.ago
    when "this_month" then 1.month.ago
    when "this_year" then 1.year.ago
    else nil
    end
  end

  def extract_youtube_id_from_related(related_video)
    # SerpApi returns video ID in different possible keys
    related_video[:id] || related_video["id"] ||
      Video.extract_youtube_id(related_video[:link] || related_video["link"] || "")
  end

  def parse_view_count(related_video)
    views_str = related_video[:views] || related_video["views"] || "0"
    # SerpApi may return "1,234 views" or "1.2M views" etc.
    views_str.to_s.gsub(/[^0-9]/, "").to_i
  end

  def import_video_by_id(youtube_id)
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
      raw_data: build_raw_data(yt_video)
    )
    video.save!
    @imported_count += 1
  rescue Yt::Errors::NoItems
    Rails.logger.warn "Related video not found: #{youtube_id}"
    @skipped_count += 1
  rescue Yt::Errors::Forbidden
    Rails.logger.warn "Access forbidden for related video: #{youtube_id}"
    @skipped_count += 1
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Could not save related video #{youtube_id}: #{e.message}"
    @skipped_count += 1
  rescue Yt::Errors::ServerError => e
    Rails.logger.warn "Server error fetching related video #{youtube_id}: #{e.message}"
    @skipped_count += 1
  end

  def extract_thumbnail_url(yt_video)
    yt_video.thumbnail_url(:maxres) ||
      yt_video.thumbnail_url(:high) ||
      yt_video.thumbnail_url(:medium) ||
      yt_video.thumbnail_url(:default)
  rescue
    nil
  end

  def build_raw_data(yt_video)
    {
      source: "related_search",
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
    { source: "related_search", error: e.message }
  end

  def broadcast_progress(message, percentage = 0)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Related Video Search",
        message: message,
        percentage: percentage,
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
        job_name: "Related Video Search",
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
        job_name: "Related Video Search",
        message: "Error: #{error_message.truncate(200)}",
        percentage: 0,
        status: :failed
      }
    )
  end
end
