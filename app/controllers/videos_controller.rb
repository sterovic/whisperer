class VideosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video, only: [:show, :destroy, :comment_frequency]

  def index
    policy_scope(Video)
    return if current_project.nil?

    current_user.update(videos_last_viewed_at: Time.current.iso8601)
    @new_channel_videos_count = 0

    @videos = current_project.videos
                             .left_joins(:comments)
                             .includes(:channel)
                             .select(
                               "videos.*",
                               "COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) AS app_comments_count",
                               "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 0 THEN 1 END) AS visible_comments_count",
                               "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 1 THEN 1 END) AS hidden_comments_count",
                               "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 2 THEN 1 END) AS removed_comments_count",
                               "COALESCE(SUM(CASE WHEN comments.parent_id IS NULL THEN comments.like_count ELSE 0 END), 0) AS total_comment_likes",
                               "MIN(CASE WHEN comments.parent_id IS NULL THEN comments.rank END) AS best_rank"
                             )
                             .group("videos.id")
                             .order(created_at: :desc)

    # Apply comment visibility filter
    @filter = params[:filter]
    @videos = apply_comment_filter(@videos, @filter)
    @videos = @videos.page(params[:page]).per(25)
  end

  def show
    authorize @video
  end

  def destroy
    authorize @video
    @video.destroy
    redirect_to videos_path, notice: "Video removed successfully"
  end

  def comment_frequency
    authorize @video, :show?
    @frequency = @video.comment_frequency(period: 7.days)
    render partial: "videos/sparkline", locals: { frequency: @frequency, video: @video }
  rescue Yt::Errors::Forbidden => e
    # Comments are disabled on this video
    render partial: "videos/sparkline_error", locals: { video: @video, error: :disabled }
  rescue Yt::Errors::NoItems, Yt::Errors::RequestError => e
    # Video not found or API error
    Rails.logger.warn "Failed to fetch comment frequency for video #{@video.id}: #{e.message}"
    render partial: "videos/sparkline_error", locals: { video: @video, error: :not_found }
  rescue => e
    Rails.logger.error "Unexpected error fetching comment frequency for video #{@video.id}: #{e.class} - #{e.message}"
    render partial: "videos/sparkline_error", locals: { video: @video, error: :unknown }
  end

  def bulk_post_comments
    authorize Comment, :create?
    @video_ids = params[:video_ids]

    if @video_ids.blank?
      redirect_to videos_path, alert: "No videos selected"
      return
    end

    job = CommentPostingJob.perform_later(
      current_user.id,
      current_project.id,
      video_ids: @video_ids,
      skip_reschedule: true
    )

    @job_id = job.job_id

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to videos_path,
                    notice: "Comment posting job started for #{@video_ids.size} video(s). Progress will appear below the table."
      end
    end
  end

  def bulk_search_related
    authorize Video, :show?
    @video_ids = params[:video_ids]

    if @video_ids.blank?
      redirect_to videos_path, alert: "No videos selected"
      return
    end

    job = RelatedVideoSearchJob.perform_later(
      current_user.id,
      current_project.id,
      video_ids: @video_ids
    )

    @job_id = job.job_id

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to videos_path,
                    notice: "Related video search started for #{@video_ids.size} video(s)."
      end
    end
  end

  def import
    authorize Video, :import?
  end

  def create_import
    authorize Video, :create?
    urls = params[:urls]

    if urls.blank?
      redirect_to import_videos_path, alert: "Please enter at least one YouTube URL"
      return
    end

    unless current_project
      redirect_to import_videos_path, alert: "Please select a project first"
      return
    end

    import_existing_comments = params[:import_existing_comments] == "1"

    job = YouTubeVideoImportJob.perform_later(
      current_user.id,
      current_project.id,
      urls,
      import_existing_comments: import_existing_comments
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "job_progress_container",
          partial: "jobs/progress",
          locals: {
            job_id: job.job_id,
            job_name: "YouTube Video Import",
            message: "Starting import...",
            percentage: 0,
            status: :running
          }
        )
      end

      format.html do
        redirect_to videos_path, notice: "Import job started. Videos will appear shortly."
      end
    end
  end

  private

  def set_video
    @video = current_project.videos.find(params[:id])
  end

  def current_project
    current_user.current_project
  end

  helper_method :current_project

  def apply_comment_filter(videos, filter)
    case filter
    when "top"
      videos.having("COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 0 THEN 1 END) > 0")
    when "newest"
      videos.having("COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 1 THEN 1 END) > 0")
    when "removed"
      videos.having("COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 2 THEN 1 END) > 0")
    when "no_comments"
      videos.having("COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) = 0")
    when "has_comments"
      videos.having("COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) > 0")
    else
      videos
    end
  end
end