class MakeGoogleAccountOptionalAndAddAuthorToComments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :comments, :google_account_id, true
    add_column :comments, :author_display_name, :string, null: false, default: ""
    add_column :comments, :author_avatar_url, :string, null: false, default: ""
  end
end
