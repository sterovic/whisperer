class JobSchedule < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :user, optional: true

  validates :job_class, presence: true, uniqueness: { scope: :project_id }
  validates :interval_minutes, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1440 }

  scope :enabled, -> { where(enabled: true) }

  after_update :manage_job_execution, if: :should_manage_job?

  def self.for(job_class_name, project)
    find_or_create_by(job_class: job_class_name.to_s, project_id: project&.id)
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

  def start!(user = nil)
    self.user = user if user
    discard_pending_jobs!
    self.last_run_at = nil
    update!(enabled: true)
  end

  def stop!
    update!(enabled: false)
    discard_pending_jobs!
  end

  def discard_pending_jobs!
    return if project_id.nil?

    GoodJob::Job
      .where(job_class: job_class, finished_at: nil, performed_at: nil)
      .where("(serialized_params->'arguments'->>1)::bigint = ?", project_id)
      .destroy_all
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
    if enabled? && user_id.present? && project_id.present?
      discard_pending_jobs!
      job_class.constantize.perform_later(user_id, project_id)
    end
  end
end
