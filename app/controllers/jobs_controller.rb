class JobsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Show available jobs and their schedules
    @scheduled_jobs = fetch_scheduled_jobs
  end

  def trigger
    # Manually trigger a job
    job = (Object.const_get params[:job_class]).perform_later(current_user.id)

    # Render initial progress card
    render turbo_stream: turbo_stream.append(
      "job_progress_container",
      partial: "jobs/progress",
      locals: {
        job_id: job.job_id,
        step: 0,
        total_steps: 5,
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
