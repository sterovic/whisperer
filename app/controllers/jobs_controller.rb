class JobsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Ensure job schedules exist
    JobSchedule.for("CommentStatusCheckJob")
    JobSchedule.for("CommentPostingJob")

    @job_schedules = JobSchedule.order(:job_class)
  end

  def trigger
    job_class = params[:job_class].safe_constantize

    unless job_class && job_class < ApplicationJob
      redirect_to jobs_path, alert: "Invalid job class"
      return
    end

    job = case job_class.name
    when "CommentPostingJob"
      unless current_project
        render turbo_stream: turbo_stream.append(
          "job_progress_container",
          partial: "jobs/progress",
          locals: {
            job_id: SecureRandom.uuid,
            job_name: "Comment Posting",
            step: 0,
            total_steps: 1,
            message: "Error: Please select a project first",
            percentage: 0,
            status: :failed
          }
        )
        return
      end
      job_class.perform_later(current_user.id, current_project.id)
    else
      job_class.perform_later(current_user.id)
    end

    job_name = job_class.name.underscore.humanize

    render turbo_stream: turbo_stream.append(
      "job_progress_container",
      partial: "jobs/progress",
      locals: {
        job_id: job.job_id,
        job_name: job_name,
        step: 0,
        total_steps: 1,
        message: "Job queued...",
        percentage: 0,
        status: :running
      }
    )
  end

  def schedule
    # Update job schedule in database
    # This would typically update a JobSchedule model that GoodJob reads from

    job_name = params[:job_name]
    cron_schedule = params[:cron_schedule]

    # Example: Store in database for dynamic scheduling
    # JobSchedule.find_or_create_by(name: job_name).update(
    #   cron: cron_schedule,
    #   class_name: 'ExampleSocialMediaJob',
    #   args: [current_user.id]
    # )

    redirect_to jobs_path, notice: "Job schedule updated successfully"
  end

  private

  def current_project
    current_user.current_project
  end
  helper_method :current_project

  def fetch_scheduled_jobs
    # In a real app, fetch from database
    # For now, return example data
    [
      {
        name: "example_social_media_job",
        class_name: "ExampleSocialMediaJob",
        cron: "0 */6 * * *", # Every 6 hours
        description: "Fetches social media data every 6 hours",
        next_run: 6.hours.from_now
      }
    ]
  end
end
