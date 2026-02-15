class AddProjectAndUserToJobSchedules < ActiveRecord::Migration[8.0]
  def change
    add_reference :job_schedules, :project, foreign_key: true, null: true
    add_reference :job_schedules, :user, foreign_key: true, null: true

    remove_index :job_schedules, :job_class
    add_index :job_schedules, [:job_class, :project_id], unique: true
  end
end
