class CreateGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :google_accounts do |t|
      t.string :google_id, null: false
      t.string :email
      t.string :name
      t.string :youtube_channel_id
      t.string :youtube_handle
      t.string :avatar_url
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :google_accounts, :google_id
    add_index :google_accounts, [:google_id, :user_id], unique: true
  end
end
