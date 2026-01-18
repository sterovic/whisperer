class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :youtube_id, null: false
      t.string :title
      t.text :description
      t.integer :comment_count, default: 0
      t.integer :like_count, default: 0
      t.integer :view_count, default: 0
      t.string :thumbnail_url
      t.datetime :fetched_at
      t.jsonb :raw_data, default: {}
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :videos, :youtube_id
    add_index :videos, [:youtube_id, :project_id], unique: true
  end
end
