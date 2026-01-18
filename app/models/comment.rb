class Comment < ApplicationRecord
  belongs_to :video
  belongs_to :google_account
  belongs_to :project
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  enum :status, { visible: 0, hidden: 1, removed: 2 }

  validates :text, presence: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  after_update_commit :broadcast_update, if: :saved_change_to_tracked_attributes?
  after_create_commit :broadcast_create

  def reply?
    parent_id.present?
  end

  def broadcast_stream_name
    "project_#{project_id}_comments"
  end

  private

  def saved_change_to_tracked_attributes?
    saved_change_to_status? || saved_change_to_like_count? || saved_change_to_rank?
  end

  def broadcast_update
    broadcast_replace_to(
      broadcast_stream_name,
      target: dom_id_for_comment,
      partial: "comments/comment_row",
      locals: { comment: self }
    )
  end

  def broadcast_create
    return if reply? # Only broadcast top-level comments

    broadcast_prepend_to(
      broadcast_stream_name,
      target: "comments_table_body",
      partial: "comments/comment_row",
      locals: { comment: self }
    )
  end

  def dom_id_for_comment
    "comment_#{id}"
  end
end

