class CreateProjectMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :project_members do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.integer :role

      t.timestamps
    end

    add_index :project_members, [:user_id, :project_id], unique: true
  end
end
