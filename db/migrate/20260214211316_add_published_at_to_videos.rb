class AddPublishedAtToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :published_at, :datetime
  end
end
