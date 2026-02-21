class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    true
  end

  def edit?
    update?
  end

  def destroy?
    true
  end

  def method_missing(method_name, *args)
    if method_name.to_s.end_with?("?")
      false
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.end_with?("?") || super
  end

  private

  def admin?
    user&.admin?
  end

  def within_limit?(resource)
    return true if admin?

    count = user.send(:"total_#{resource}_count")
    user.within_plan_limit?(resource, count)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
