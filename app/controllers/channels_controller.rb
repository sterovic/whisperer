class ChannelsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  def index
    return if current_project.nil?

    @channels = current_project.channels.with_stats.order("videos_count DESC").page(params[:page]).per(25)
    @channel_stats = Channel.find_by_sql([<<~SQL, current_project.id]).first
      SELECT
        COUNT(*) AS total_channels,
        COALESCE(SUM(sub.comments_count), 0) AS total_comments,
        ROUND(AVG(sub.success_rate), 1) AS avg_success_rate,
        MIN(sub.best_rank) AS best_rank
      FROM (
        SELECT
          channels.id,
          COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) AS comments_count,
          ROUND(
            COUNT(CASE WHEN comments.parent_id IS NULL AND comments.appearance = 0 THEN 1 END) * 100.0
            / NULLIF(COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END), 0),
            1
          ) AS success_rate,
          MIN(CASE WHEN comments.parent_id IS NULL THEN comments.rank END) AS best_rank
        FROM channels
        LEFT OUTER JOIN videos ON videos.channel_id = channels.id
        LEFT OUTER JOIN comments ON comments.video_id = videos.id
        WHERE channels.project_id = ?
        GROUP BY channels.id
      ) sub
    SQL
  end

  private

  def current_project
    current_user.current_project
  end

  helper_method :current_project
end
