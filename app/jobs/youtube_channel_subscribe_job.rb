class YouTubeChannelSubscribeJob < ApplicationJob
  queue_as :default

  def perform(channel_subscription_id)
    @subscription = ChannelSubscription.find(channel_subscription_id)

    activate_subscription
  end

  private

  def activate_subscription
    @subscription.update!(
      status: :active,
      subscribed_at: Time.current
    )
    Rails.logger.info "Successfully activated subscription for channel #{@subscription.channel_id}"

    @subscription.fetch_channel_metadata!

    channel = @subscription.project.channels.find_or_initialize_by(
      youtube_channel_id: @subscription.channel_id
    )
    channel.update!(
      name: @subscription.channel_name,
      thumbnail_url: @subscription.channel_thumbnail_url,
      subscriber_count: @subscription.subscriber_count,
      video_count: @subscription.video_count
    )
  rescue StandardError => e
    @subscription.update!(status: :failed)
    Rails.logger.error "Error activating subscription for channel #{@subscription.channel_id}: #{e.message}"
  end
end
