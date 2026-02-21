module ApplicationHelper
  include DashboardHelper

  def reach_chart_data(comment, max_samples: 12)
    snapshots = comment.snapshots.order(:created_at)
                       .select(:rank, :video_views, :like_count, :reach, :created_at)

    sampled = if snapshots.size <= max_samples
                snapshots.to_a
              else
                indices = (0...max_samples).map { |i| (i * (snapshots.size - 1).to_f / (max_samples - 1)).round }
                indices.map { |i| snapshots[i] }
              end

    sampled.map do |s|
      { rank: s.rank, video_views: s.video_views, like_count: s.like_count,
        reach: s.reach, created_at: s.created_at.iso8601 }
    end
  end
end
