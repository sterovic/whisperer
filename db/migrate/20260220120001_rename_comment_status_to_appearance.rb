class RenameCommentStatusToAppearance < ActiveRecord::Migration[8.0]
  def change
    rename_column :comments, :status, :appearance
  end
end
