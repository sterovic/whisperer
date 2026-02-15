class ChannelSubscription < ApplicationRecord
  belongs_to :project

  enum :status, { pending: 0, active: 1, failed: 3 }

  validates :channel_id, presence: true
  validates :channel_id, uniqueness: { scope: :project_id, message: "is already subscribed in this project" }
  validates :initial_import_limit, numericality: { in: 1..15 }

  scope :active_subscriptions, -> { where(status: :active) }

  # Count videos imported from this channel in the project
  def imported_videos_count
    @imported_videos_count ||= project.videos.joins(:channel).where(channels: { youtube_channel_id: channel_id }).count
  end

  # Get recent videos from this channel
  def recent_videos(limit: 5)
    project.videos.joins(:channel).where(channels: { youtube_channel_id: channel_id }).order(created_at: :desc).limit(limit)
  end

  # Fetch and update channel metadata from YouTube API
  def fetch_channel_metadata!
    channel = Yt::Channel.new(id: channel_id)

    update!(
      channel_name: channel.title,
      channel_thumbnail_url: channel.thumbnail_url,
      subscriber_count: channel.subscriber_count,
      video_count: channel.video_count
    )
  rescue Yt::Errors::NoItems, Yt::Errors::Forbidden => e
    Rails.logger.warn "Could not fetch channel metadata for #{channel_id}: #{e.message}"
  end

  # Extract channel ID from various URL formats or raw ID
  def self.extract_channel_id(input)
    return nil if input.blank?

    input = input.strip

    # Already a channel ID (starts with UC and is 24 chars)
    return input if input.match?(/\AUC[a-zA-Z0-9_-]{22}\z/)

    # YouTube channel URL formats
    patterns = [
      %r{youtube\.com/channel/(UC[a-zA-Z0-9_-]{22})},
      %r{youtube\.com/@([^/?]+)}, # Handle @username format - needs API lookup
      %r{youtube\.com/c/([^/?]+)}, # Custom URL format - needs API lookup
      %r{youtube\.com/user/([^/?]+)} # Legacy username format - needs API lookup
    ]

    patterns.each do |pattern|
      match = input.match(pattern)
      return match[1] if match && match[1].start_with?("UC")
    end

    # If it's a @handle, /c/, or /user/ URL, we'd need to look it up via API
    # For now, return nil for these cases
    nil
  end

  def active?
    status == "active"
  end

  def display_name
    channel_name.presence || channel_id
  end
end
