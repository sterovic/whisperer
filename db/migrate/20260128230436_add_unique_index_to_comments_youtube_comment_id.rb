class AddUniqueIndexToCommentsYouTubeCommentId < ActiveRecord::Migration[8.0]
  def change
    # Remove existing non-unique index first
    remove_index :comments, :youtube_comment_id, if_exists: true

    # Add unique index (PostgreSQL allows multiple NULLs in unique indexes by default)
    add_index :comments, :youtube_comment_id, unique: true
  end
end
