class AddTimestampsToGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :google_accounts, :authorized_at, :datetime
    add_column :google_accounts, :reauthorized_at, :datetime
    add_column :google_accounts, :last_used_at, :datetime

    reversible do |dir|
      dir.up do
        execute "UPDATE google_accounts SET authorized_at = created_at WHERE authorized_at IS NULL"
      end
    end
  end
end
