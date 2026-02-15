class FetchVideoMetadataJob < ApplicationJob
  queue_as :default

  def perform(video_id)
    video = Video.find(video_id)

    yt_video = Yt::Video.new(id: video.youtube_id)

    video.update!(
      title: yt_video.title,
      description: yt_video.description,
      like_count: yt_video.like_count || 0,
      comment_count: yt_video.comment_count || 0,
      view_count: yt_video.view_count || 0,
      thumbnail_url: extract_thumbnail_url(yt_video),
      published_at: yt_video.published_at,
      fetched_at: Time.current,
      raw_data: build_raw_data(yt_video)
    )

    channel = Channel.find_or_create_from_yt_video!(video.project, yt_video)
    video.update_column(:channel_id, channel.id) if channel && video.channel_id != channel.id

    Rails.logger.info "FetchVideoMetadataJob: Updated metadata for video #{video.youtube_id}"
  rescue Yt::Errors::NoItems
    Rails.logger.warn "FetchVideoMetadataJob: Video not found #{video.youtube_id}"
  rescue Yt::Errors::Forbidden
    Rails.logger.warn "FetchVideoMetadataJob: Access forbidden for video #{video.youtube_id}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "FetchVideoMetadataJob: Video record #{video_id} no longer exists"
  end

  private

  def extract_thumbnail_url(yt_video)
    yt_video.thumbnail_url(:maxres) ||
      yt_video.thumbnail_url(:high) ||
      yt_video.thumbnail_url(:medium) ||
      yt_video.thumbnail_url(:default)
  rescue
    nil
  end

  def build_raw_data(yt_video)
    {
      source: "channel_poll",
      channel_id: yt_video.channel_id,
      channel_title: yt_video.channel_title,
      published_at: yt_video.published_at&.iso8601,
      duration: yt_video.duration,
      view_count: yt_video.view_count,
      tags: yt_video.tags,
      category_id: yt_video.category_id,
      category_title: yt_video.category_title,
      live_broadcast_content: yt_video.live_broadcast_content
    }
  rescue => e
    { source: "channel_poll", error: e.message }
  end
end
