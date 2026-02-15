class Channel < ApplicationRecord
  belongs_to :project
  has_many :videos

  validates :youtube_channel_id, presence: true, uniqueness: { scope: :project_id }

  scope :with_stats, -> {
    left_joins(videos: :comments)
      .select(
        "channels.*",
        "COUNT(DISTINCT videos.id) AS videos_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) AS comments_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 0 THEN 1 END) AS visible_comments_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 1 THEN 1 END) AS hidden_comments_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 2 THEN 1 END) AS removed_comments_count",
        "ROUND(COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 0 THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END), 0), 1) AS success_rate",
        "MIN(CASE WHEN comments.parent_id IS NULL THEN comments.rank END) AS best_rank",
        "COALESCE(SUM(CASE WHEN comments.parent_id IS NULL THEN comments.like_count ELSE 0 END), 0) AS total_likes"
      )
      .group("channels.id")
  }

  def subscribed?
    project.channel_subscriptions.exists?(channel_id: youtube_channel_id)
  end

  def self.find_or_create_from_yt_video!(project, yt_video)
    yt_channel_id = yt_video.channel_id
    return nil if yt_channel_id.blank?

    channel = project.channels.find_or_initialize_by(youtube_channel_id: yt_channel_id)
    if channel.new_record?
      channel.name = yt_video.channel_title
      channel.save!
    end
    channel
  rescue ActiveRecord::RecordNotUnique
    project.channels.find_by!(youtube_channel_id: yt_channel_id)
  end
end
