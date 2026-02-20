class JobSchedulesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_job_schedule, only: [:update, :toggle, :run_now]

  def update
    if @job_schedule.update(job_schedule_params)
      redirect_to jobs_path, notice: "Schedule updated successfully"
    else
      redirect_to jobs_path, alert: @job_schedule.errors.full_messages.join(", ")
    end
  end

  def toggle
    if @job_schedule.enabled?
      @job_schedule.stop!
      redirect_to jobs_path, notice: "#{@job_schedule.job_name} stopped"
    else
      @job_schedule.start!(current_user)
      redirect_to jobs_path, notice: "#{@job_schedule.job_name} started"
    end
  end

  def run_now
    unless current_project
      redirect_to jobs_path, alert: "Please select a project first"
      return
    end

    job_class = @job_schedule.job_class.constantize
    job_class.perform_later(current_user.id, current_project.id, { skip_reschedule: true })

    redirect_to jobs_path, notice: "#{@job_schedule.job_name} triggered"
  end

  private

  def current_project
    current_user.current_project
  end

  def set_job_schedule
    @job_schedule = JobSchedule.find(params[:id])
  end

  def job_schedule_params
    params.require(:job_schedule).permit(:interval_minutes)
  end
end
