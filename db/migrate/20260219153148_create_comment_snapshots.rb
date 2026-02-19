class CreateCommentSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :comment_snapshots do |t|
      t.references :comment, null: false, foreign_key: true
      t.integer :rank
      t.integer :video_views
      t.integer :like_count
      t.integer :reach, default: 0

      t.datetime :created_at, null: false
    end

    add_column :comments, :total_reach, :integer, default: 0
    add_column :comments, :last_snapshot_at, :datetime
  end
end
