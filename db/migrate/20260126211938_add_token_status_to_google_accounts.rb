class AddTokenStatusToGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :google_accounts, :token_status, :integer, default: 0, null: false
    add_index :google_accounts, :token_status
  end
end
