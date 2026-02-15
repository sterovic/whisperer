class CreateChannelsAndAddChannelIdToVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :channels do |t|
      t.references :project, null: false, foreign_key: true
      t.string :youtube_channel_id, null: false
      t.string :name
      t.string :thumbnail_url
      t.string :custom_url
      t.text :description
      t.integer :subscriber_count
      t.integer :video_count
      t.timestamps
    end

    add_index :channels, [:project_id, :youtube_channel_id], unique: true

    add_reference :videos, :channel, foreign_key: true, null: true
  end
end
