class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true
      t.string :stripe_subscription_id
      t.string :stripe_customer_id
      t.integer :status, default: 0
      t.integer :billing_cycle, default: 0
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :canceled_at
      t.datetime :trial_ends_at

      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :stripe_customer_id
  end
end
