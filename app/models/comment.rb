class Comment < ApplicationRecord
  belongs_to :video
  belongs_to :google_account, optional: true
  belongs_to :project
  belongs_to :parent, class_name: "Comment", optional: true, touch: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy
  has_many :snapshots, class_name: "CommentSnapshot", dependent: :delete_all
  has_many :smm_orders, dependent: :nullify

  enum :appearance, { top: 0, newest: 1, removed: 2 }
  enum :post_type, { via_api: 0, via_smm: 1, manual: 2 }

  validates :text, presence: true

  scope :top_level, -> { where(parent_id: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  after_update_commit :broadcast_update, if: :saved_change_to_tracked_attributes?
  after_create_commit :broadcast_create
  after_touch -> { reload; broadcast_update }

  def self.import!(comment_data, video, post_type:)
    insert_all!(comment_data.map { |data| {
      video_id: video.id,
      youtube_comment_id: data[:id],
      text: data[:text],
      author_display_name: data[:author],
      author_avatar_url: data[:image_url],
      project_id: video.project_id,
      post_type: post_types[post_type]
    } })
  end

  def reply?
    parent_id.present?
  end

  def record_snapshot!(rank:, like_count:, video_views:)
    previous_views = snapshots.order(created_at: :desc).pick(:video_views) || 0
    view_delta = [video_views - previous_views, 0].max

    reach = CommentReachCalculator.calculate(view_delta: view_delta, position: rank)

    snapshot = snapshots.create!(
      rank: rank,
      video_views: video_views,
      like_count: like_count,
      reach: reach
    )

    update_columns(
      total_reach: total_reach + reach,
      last_snapshot_at: snapshot.created_at
    )
  end

  # TODO: Remove once real snapshots are flowing
  def mock_snapshot_data(count: 12)
    rng = Random.new(id || 0) # stable per-comment so it doesn't change on reload
    video_views = rng.rand(1_000..50_000)
    likes = rng.rand(0..20)
    rank = rng.rand(1..15)

    count.times.map do |i|
      view_delta = rng.rand(500..5_000)
      video_views += view_delta
      likes += rng.rand(0..3)
      rank = (rank + rng.rand(-2..2)).clamp(1, 30)
      reach = CommentReachCalculator.calculate(view_delta: view_delta, position: rank)

      { rank: rank, video_views: video_views, like_count: likes, reach: reach, created_at: (count - i).hours.ago.iso8601 }
    end
  end

  def broadcast_stream_name
    "project_#{project_id}_comments"
  end

  private

  def saved_change_to_tracked_attributes?
    saved_change_to_appearance? || saved_change_to_like_count? || saved_change_to_rank? || saved_change_to_total_reach?
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

