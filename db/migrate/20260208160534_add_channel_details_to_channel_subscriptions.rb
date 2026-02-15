class AddChannelDetailsToChannelSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :channel_subscriptions, :channel_thumbnail_url, :string
    add_column :channel_subscriptions, :subscriber_count, :integer
    add_column :channel_subscriptions, :video_count, :integer
  end
end
