class SmmOrder < ApplicationRecord
  belongs_to :smm_panel_credential
  belongs_to :project
  belongs_to :video, optional: true
  belongs_to :comment, optional: true

  enum :service_type, { comment: 0, upvote: 1 }
  enum :status, {
    pending: 0,
    in_progress: 1,
    processing: 2,
    completed: 3,
    partial: 4,
    canceled: 5,
    refunded: 6,
    failed: 7
  }

  validates :service_type, presence: true
  validates :external_order_id, uniqueness: true, allow_nil: true

  scope :uncompleted, -> { where(status: [:pending, :in_progress, :processing]) }
  scope :for_project, ->(project) { where(project: project) }
  scope :recent, -> { order(created_at: :desc) }

  def panel_type
    smm_panel_credential&.panel_type
  end

  def placed_for_comments?
    service_type == "comment"
  end

  def status_badge_class
    case status
    when "completed"
      "badge-success"
    when "partial"
      "badge-warning"
    when "canceled", "refunded", "failed"
      "badge-error"
    when "in_progress", "processing"
      "badge-info"
    else
      "badge-ghost"
    end
  end

  def update_from_api_response(response)
    self.charge = response[:charge]
    self.start_count = response[:start_count]
    self.remains = response[:remains]
    self.currency = response[:currency]
    self.status = normalize_status(response[:status])
    self.raw_response = response
    save!
  end

  private

  def normalize_status(api_status)
    case api_status&.downcase
    when "pending"
      :pending
    when "in progress"
      :in_progress
    when "processing"
      :processing
    when "completed"
      :completed
    when "partial"
      :partial
    when "canceled"
      :canceled
    when "refunded"
      :refunded
    else
      :failed
    end
  end
end