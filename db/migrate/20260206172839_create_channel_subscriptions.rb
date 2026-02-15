class CreateChannelSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :channel_subscriptions do |t|
      t.references :project, null: false, foreign_key: true
      t.string :channel_id, null: false
      t.string :channel_name
      t.datetime :subscribed_at
      t.datetime :expires_at
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :channel_subscriptions, [:project_id, :channel_id], unique: true
    add_index :channel_subscriptions, :channel_id
  end
end
