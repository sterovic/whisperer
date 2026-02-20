class CommentPolicy < ApplicationPolicy
  def create?
    within_limit?(:comments)
  end

  def reply?
    create?
  end

  def upvote?
    true
  end

  class Scope < ApplicationPolicy::Scope
  end
end
