class CreatePlans < ActiveRecord::Migration[8.0]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :price_monthly_cents, default: 0
      t.integer :price_yearly_cents, default: 0
      t.string :stripe_monthly_price_id
      t.string :stripe_yearly_price_id
      t.integer :max_projects
      t.integer :max_videos
      t.integer :max_comments
      t.integer :max_google_accounts
      t.jsonb :metadata, default: {}
      t.integer :sort_order

      t.timestamps
    end

    add_index :plans, :slug, unique: true
  end
end
