class AddPostTypeToComments < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :post_type, :integer, default: 0
  end
end
