class ProjectPolicy < ApplicationPolicy
  def create?
    within_limit?(:projects)
  end

  def switch?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:project_members).where(project_members: { user_id: user.id })
    end
  end
end
