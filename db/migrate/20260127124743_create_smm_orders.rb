class CreateSmmOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :smm_orders do |t|
      t.references :smm_panel_credential, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.references :video, foreign_key: true
      t.references :comment, foreign_key: true
      t.string :external_order_id
      t.integer :service_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :quantity
      t.decimal :charge, precision: 10, scale: 5
      t.integer :start_count
      t.integer :remains
      t.string :currency
      t.string :link
      t.jsonb :raw_response, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :smm_orders, :external_order_id
    add_index :smm_orders, :status
    add_index :smm_orders, :service_type
  end
end
