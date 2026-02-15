class AddInitialImportLimitToChannelSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :channel_subscriptions, :initial_import_limit, :integer, default: 3, null: false
  end
end
