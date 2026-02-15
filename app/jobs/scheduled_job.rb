class ScheduledJob < ApplicationJob
  class_attribute :job_display_name, default: "Scheduled Job"

  def perform(user_id, project_id, options = {})
    options = options.symbolize_keys
    @_skip_reschedule = options[:skip_reschedule]

    @user = User.find(user_id)
    @project = Project.find(project_id)
    @job_id = provider_job_id || job_id

    unless @_skip_reschedule
      schedule = JobSchedule.find_by(job_class: self.class.name, project_id: project_id)

      # Atomic claim: only one job instance wins the race
      claimed = JobSchedule.where(job_class: self.class.name, project_id: project_id)
        .where("last_run_at IS NULL OR last_run_at <= ?", (schedule.interval_minutes / 2.0).minutes.ago)
        .update_all(last_run_at: Time.current)

      if claimed == 0
        Rails.logger.info "#{self.class.name}: Skipping - another instance already claimed this slot"
        return
      end
    end

    execute(options)
  ensure
    reschedule(user_id, project_id) unless @_skip_reschedule
  end

  private

  # Subclasses implement this
  def execute(options)
    raise NotImplementedError
  end

  def reschedule(user_id, project_id)
    schedule = JobSchedule.find_by(job_class: self.class.name, project_id: project_id)
    if schedule&.enabled?
      self.class.set(wait: schedule.interval_minutes.minutes).perform_later(user_id, project_id)
    end
  rescue => e
    Rails.logger.error "#{self.class.name}: Failed to reschedule: #{e.message}"
  end
end
