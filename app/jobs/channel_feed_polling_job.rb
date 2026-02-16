class ChannelFeedPollingJob < ScheduledJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "#{self.class.name}-#{arguments.second}" }
  )

  self.job_display_name = "Channel Feed Polling"

  private

  def execute(options)
    subscriptions = @project.channel_subscriptions.active
    Rails.logger.info "ChannelFeedPollingJob: Polling #{subscriptions.count} active channel subscriptions for project #{@project.id}"

    subscriptions.find_each do |subscription|
      poll_channel_feed(subscription)
    rescue StandardError => e
      Rails.logger.error "ChannelFeedPollingJob: Error polling channel #{subscription.channel_id}: #{e.message}"
    end
  end

  def poll_channel_feed(subscription)
    require "rss"
    require "net/http"

    feed_url = "https://www.youtube.com/feeds/videos.xml?channel_id=#{subscription.channel_id}"
    uri = URI(feed_url)
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn "ChannelFeedPollingJob: HTTP #{response.code} for channel #{subscription.channel_id}"
      return
    end

    feed = RSS::Parser.parse(response.body, false)
    project = subscription.project
    channel = project.channels.find_by(youtube_channel_id: subscription.channel_id)
    first_poll = channel.nil? || project.videos.where(channel: channel).none?
    import_limit = first_poll ? subscription.initial_import_limit : nil
    new_videos_count = 0

    feed.items.each do |item|
      break if import_limit && new_videos_count >= import_limit

      video_id = extract_video_id(item)
      next if video_id.blank?

      # Feed is newest-first; stop once we hit a known video
      break if !first_poll && project.videos.exists?(youtube_id: video_id)

      video = project.videos.create!(
        youtube_id: video_id,
        title: item.title&.content,
        channel: channel,
        fetched_at: nil,
        raw_data: { source: "channel_poll" }
      )

      FetchVideoMetadataJob.perform_later(video.id)
      new_videos_count += 1
    end

    Rails.logger.info "ChannelFeedPollingJob: Found #{new_videos_count} new videos for channel #{subscription.channel_id}" if new_videos_count > 0
  rescue RSS::Error => e
    Rails.logger.error "ChannelFeedPollingJob: RSS parse error for channel #{subscription.channel_id}: #{e.message}"
  end

  def extract_video_id(item)
    id_content = item.id&.content
    return nil if id_content.blank?

    if id_content.start_with?("yt:video:")
      id_content.sub("yt:video:", "")
    else
      Video.extract_youtube_id(item.link&.href)
    end
  end
end
