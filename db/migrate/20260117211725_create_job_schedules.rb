class CreateJobSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :job_schedules do |t|
      t.string :job_class, null: false
      t.integer :interval_minutes, default: 10, null: false
      t.boolean :enabled, default: false, null: false
      t.datetime :last_run_at

      t.timestamps
    end

    add_index :job_schedules, :job_class, unique: true
    add_index :job_schedules, :enabled
  end
end
