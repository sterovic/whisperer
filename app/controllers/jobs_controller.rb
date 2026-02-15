class JobsController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_project
      # Ensure job schedules exist for current project
      JobSchedule.for("CommentStatusCheckJob", current_project)
      JobSchedule.for("CommentPostingJob", current_project)
      JobSchedule.for("SmmOrderStatusCheckJob", current_project)
      JobSchedule.for("ChannelFeedPollingJob", current_project)

      @job_schedules = JobSchedule.where(project: current_project).order(:job_class)
    else
      @job_schedules = JobSchedule.none
    end
  end

  def trigger
    job_class = params[:job_class].safe_constantize

    unless job_class && job_class < ApplicationJob
      redirect_to jobs_path, alert: "Invalid job class"
      return
    end

    unless current_project
      render turbo_stream: turbo_stream.append(
        "job_progress_container",
        partial: "jobs/progress",
        locals: {
          job_id: SecureRandom.uuid,
          job_name: job_class.name.underscore.humanize,
          message: "Error: Please select a project first",
          percentage: 0,
          status: :failed
        }
      )
      return
    end

    job = job_class.perform_later(current_user.id, current_project.id)
    job_name = job_class.name.underscore.humanize

    render turbo_stream: turbo_stream.append(
      "job_progress_container",
      partial: "jobs/progress",
      locals: {
        job_id: job.job_id,
        job_name: job_name,
        message: "Job queued...",
        percentage: 0,
        status: :running
      }
    )
  end

  def schedule
    job_name = params[:job_name]
    cron_schedule = params[:cron_schedule]

    redirect_to jobs_path, notice: "Job schedule updated successfully"
  end

  private

  def current_project
    current_user.current_project
  end

  helper_method :current_project
end
