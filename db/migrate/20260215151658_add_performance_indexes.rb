class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :comments, [:project_id, :status, :parent_id],
              name: "index_comments_on_project_status_parent",
              algorithm: :concurrently

    add_index :comments, [:video_id, :youtube_comment_id],
              name: "index_comments_on_video_id_and_yt_comment_id",
              algorithm: :concurrently

    add_index :videos, [:project_id, :channel_id],
              name: "index_videos_on_project_id_and_channel_id",
              algorithm: :concurrently

    add_index :smm_orders, [:project_id, :status],
              name: "index_smm_orders_on_project_id_and_status",
              algorithm: :concurrently
  end
end
