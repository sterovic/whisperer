class VideoPolicy < ApplicationPolicy
  def create?
    within_limit?(:videos)
  end

  def import?
    true
  end

  class Scope < ApplicationPolicy::Scope
  end
end
