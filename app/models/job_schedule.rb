class JobSchedule < ApplicationRecord
  validates :job_class, presence: true, uniqueness: true
  validates :interval_minutes, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1440 }

  scope :enabled, -> { where(enabled: true) }

  after_update :manage_job_execution, if: :should_manage_job?

  def self.for(job_class_name)
    find_or_create_by(job_class: job_class_name.to_s)
  end

  def due?
    return false unless enabled?
    return true if last_run_at.nil?

    last_run_at < interval_minutes.minutes.ago
  end

  def recently_ran?
    return false if last_run_at.nil?

    # Consider "recently ran" if within half the interval
    last_run_at > (interval_minutes / 2.0).minutes.ago
  end

  def start!
    update!(enabled: true)
  end

  def stop!
    update!(enabled: false)
  end

  def job_name
    job_class.underscore.humanize
  end

  def next_run_at
    return nil unless enabled?
    return Time.current if last_run_at.nil?

    last_run_at + interval_minutes.minutes
  end

  def status
    return :stopped unless enabled?
    return :starting if last_run_at.nil?

    :running
  end

  private

  def should_manage_job?
    saved_change_to_enabled? || (enabled? && saved_change_to_interval_minutes?)
  end

  def manage_job_execution
    if enabled?
      # Start the job chain (or restart with new interval)
      job_class.constantize.perform_later
    end
    # When disabled, the job will check the enabled status and stop re-enqueuing
  end
end
