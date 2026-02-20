class VideoQuerySearchJob < ApplicationJob
  queue_as :default

  def perform(user_id, project_id, options = {})
    options = options.symbolize_keys
    @user = User.find(user_id)
    @project = Project.find(project_id)
    @job_id = provider_job_id || job_id

    query = options[:query]
    max_results = (options[:max_results] || 10).to_i
    order = options[:order] || "relevance"
    published_after = parse_published_after(options[:published_after])
    video_duration = options[:video_duration].presence
    video_definition = options[:video_definition].presence
    region_code = options[:region_code].presence
    min_views = (options[:min_views] || 0).to_i
    min_comments = (options[:min_comments] || 0).to_i

    if query.blank?
      broadcast_error("Search query is required")
      return
    end

    @imported_count = 0
    @skipped_count = 0

    begin
      broadcast_progress("Searching YouTube for \"#{query.truncate(40)}\"...", 5)

      search_params = { q: query, order: order, type: "video" }
      search_params[:published_after] = published_after.iso8601 if published_after
      search_params[:video_duration] = video_duration if video_duration
      search_params[:video_definition] = video_definition if video_definition
      search_params[:region_code] = region_code if region_code

      videos = Yt::Collections::Videos.new
      results = videos.where(search_params)

      # Fetch more than needed to account for filtering
      fetch_count = [max_results * 3, 50].min
      candidates = results.first(fetch_count)

      broadcast_progress("Found #{candidates.size} candidates, applying filters...", 20)

      @limit_hit = false

      candidates.each_with_index do |yt_video, index|
        break if @imported_count >= max_results
        break if @limit_hit

        percentage = 20 + ((index.to_f / candidates.size) * 70).to_i

        # Apply client-side filters
        if min_views > 0 && (yt_video.view_count || 0) < min_views
          @skipped_count += 1
          next
        end

        if min_comments > 0 && (yt_video.comment_count || 0) < min_comments
          @skipped_count += 1
          next
        end

        broadcast_progress("Importing #{@imported_count + 1}/#{max_results}: #{yt_video.title&.truncate(40)}", percentage)
        import_video(yt_video)
      end

      message = "Imported #{@imported_count} video(s)"
      message += ", skipped #{@skipped_count} (filtered)" if @skipped_count > 0
      message += ". Video limit reached for your #{@user.current_plan.name} plan." if @limit_hit
      broadcast_completion(success: true, message: message)

    rescue StandardError => e
      Rails.logger.error "VideoQuerySearchJob error: #{e.message}\n#{e.backtrace.join("\n")}"
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

  def video_limit_reached?
    return false if @user.admin?

    plan = @user.current_plan
    return false if plan.unlimited?(:videos)

    @user.total_videos_count >= plan.limit_for(:videos)
  end

  def import_video(yt_video)
    video = @project.videos.find_or_initialize_by(youtube_id: yt_video.id)

    if video.new_record? && video_limit_reached?
      @limit_hit = true
      return
    end

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
  rescue Yt::Errors::NoItems => e
    Rails.logger.warn "Video not found: #{yt_video.id}"
    @skipped_count += 1
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Access forbidden for video: #{yt_video.id}"
    @skipped_count += 1
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Could not save video #{yt_video.id}: #{e.message}"
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
      source: "query_search",
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
    { source: "query_search", error: e.message }
  end

  def broadcast_progress(message, percentage = 0)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Video Search",
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
        job_name: "Video Search",
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
        job_name: "Video Search",
        message: "Error: #{error_message.truncate(200)}",
        percentage: 0,
        status: :failed
      }
    )
  end
end
