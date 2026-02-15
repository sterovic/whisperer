class RemoveExpiresAtFromChannelSubscriptions < ActiveRecord::Migration[8.0]
  def change
    remove_column :channel_subscriptions, :expires_at, :datetime
  end
end
