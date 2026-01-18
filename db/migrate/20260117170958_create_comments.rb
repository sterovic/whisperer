class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.string :youtube_comment_id
      t.text :text, null: false
      t.references :video, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :comments }
      t.integer :status, default: 0, null: false
      t.integer :like_count, default: 0
      t.integer :rank
      t.references :google_account, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :comments, :youtube_comment_id
    add_index :comments, :status
    add_index :comments, [:video_id, :parent_id]
  end
end
