class VideoSearchesController < ApplicationController
  before_action :authenticate_user!

  def index
    @videos = current_project&.videos&.order(created_at: :desc) || []
  end

  def create
    unless current_project
      redirect_to video_searches_path, alert: "Please select a project first"
      return
    end

    query = params[:query]
    if query.blank?
      redirect_to video_searches_path, alert: "Please enter a search query"
      return
    end

    job = VideoQuerySearchJob.perform_later(
      current_user.id,
      current_project.id,
      query: query,
      max_results: params[:max_results],
      order: params[:order],
      published_after: params[:published_after],
      video_duration: params[:video_duration],
      video_definition: params[:video_definition],
      region_code: params[:region_code],
      min_views: params[:min_views],
      min_comments: params[:min_comments]
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "job_progress_container",
          partial: "jobs/progress",
          locals: {
            job_id: job.job_id,
            job_name: "Video Search",
            message: "Starting search for \"#{query.truncate(30)}\"...",
            percentage: 0,
            status: :running
          }
        )
      end
      format.html do
        redirect_to video_searches_path, notice: "Search job started."
      end
    end
  end

  def search_related
    unless current_project
      redirect_to video_searches_path, alert: "Please select a project first"
      return
    end

    video_ids = params[:video_ids]
    if video_ids.blank?
      redirect_to video_searches_path, alert: "Please select at least one video"
      return
    end

    job = RelatedVideoSearchJob.perform_later(
      current_user.id,
      current_project.id,
      video_ids: video_ids,
      max_results: params[:max_results],
      published_after: params[:published_after],
      min_views: params[:min_views],
      min_comments: params[:min_comments]
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "job_progress_container",
          partial: "jobs/progress",
          locals: {
            job_id: job.job_id,
            job_name: "Related Video Search",
            message: "Starting related video search for #{video_ids.size} video(s)...",
            percentage: 0,
            status: :running
          }
        )
      end
      format.html do
        redirect_to video_searches_path, notice: "Related video search job started."
      end
    end
  end

  def autocomplete
    query = params[:q].to_s.strip
    if query.blank?
      render json: []
      return
    end

    require "net/http"
    require "uri"
    require "json"

    uri = URI("https://suggestqueries.google.com/complete/search")
    uri.query = URI.encode_www_form(client: "youtube", ds: "yt", q: query, hl: "en")

    response = Net::HTTP.get(uri)

    # Response is JSONP: window.google.ac.h(["query",[["suggestion1",...],["suggestion2",...],...]])
    # Extract JSON between first ( and last )
    json_str = response[response.index("(") + 1...response.rindex(")")]
    data = JSON.parse(json_str)

    # data[1] contains arrays of suggestions, each is ["suggestion_text", ...]
    suggestions = (data[1] || []).map { |s| s[0] }.compact.first(8)

    render json: suggestions
  rescue => e
    Rails.logger.warn "Autocomplete error: #{e.message}"
    render json: []
  end

  private

  def current_project
    current_user.current_project
  end

  helper_method :current_project
end
