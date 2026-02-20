class GoogleAccountPolicy < ApplicationPolicy
  def create?
    within_limit?(:google_accounts)
  end

  def connect?
    create?
  end

  class Scope < ApplicationPolicy::Scope
  end
end
