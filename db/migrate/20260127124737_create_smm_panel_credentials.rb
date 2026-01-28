class CreateSmmPanelCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :smm_panel_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :panel_type, null: false
      t.string :api_key, null: false
      t.string :comment_service_id
      t.string :upvote_service_id

      t.timestamps
    end

    add_index :smm_panel_credentials, [:user_id, :panel_type], unique: true
  end
end
