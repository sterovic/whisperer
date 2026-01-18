class VideosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_video, only: [:show, :destroy]

  def index
    @videos = current_project.videos.order(created_at: :desc)
  end

  def show
  end

  def destroy
    @video.destroy
    redirect_to videos_path, notice: "Video removed successfully"
  end

  def import
    # Show the import form
  end

  def create_import
    urls = params[:urls]

    if urls.blank?
      redirect_to import_videos_path, alert: "Please enter at least one YouTube URL"
      return
    end

    unless current_project
      redirect_to import_videos_path, alert: "Please select a project first"
      return
    end

    job = YouTubeVideoImportJob.perform_later(
      current_user.id,
      current_project.id,
      urls
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "job_progress_container",
          partial: "jobs/progress",
          locals: {
            job_id: job.job_id,
            job_name: "YouTube Video Import",
            step: 0,
            total_steps: 1,
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
end