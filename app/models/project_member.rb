class ProjectMember < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :role, { viewer: 0, editor: 1, owner: 2 }

  validates :user_id, uniqueness: { scope: :project_id, message: "is already a member" }
end
