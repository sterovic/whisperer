class User < ApplicationRecord
  has_many :project_members, dependent: :destroy
  has_many :projects, through: :project_members
  has_many :google_accounts, dependent: :destroy
  has_many :smm_panel_credentials, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_one :active_subscription, -> { current.order(created_at: :desc) }, class_name: "Subscription"

  enum :role, { user: 0, admin: 1 }

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  # Validations
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Custom password validation
  validate :password_complexity

  store_accessor :preferences,
                 :current_project_id,
                 :videos_last_viewed_at

  def full_name
    "#{first_name} #{last_name}"
  end

  def current_project
    return nil unless current_project_id
    projects.find_by(id: current_project_id)
  end

  def current_project=(project)
    self.current_project_id = project&.id
    save
  end

  def current_plan
    active_subscription&.plan || Plan.free
  end

  def within_plan_limit?(resource, current_count)
    return true if admin?

    plan = current_plan
    return true if plan.unlimited?(resource)

    current_count < plan.limit_for(resource)
  end

  def total_projects_count
    projects.count
  end

  def total_videos_count
    Video.where(project_id: projects.select(:id)).count
  end

  def total_comments_count
    Comment.where(project_id: projects.select(:id))
           .where(parent_id: nil)
           .count
  end

  def total_google_accounts_count
    google_accounts.count
  end

  private

  def password_complexity
    return if password.blank?

    errors.add :password, "must include at least one lowercase letter" unless password.match?(/[a-z]/)
    errors.add :password, "must include at least one uppercase letter" unless password.match?(/[A-Z]/)
    errors.add :password, "must include at least one digit" unless password.match?(/\d/)
    errors.add :password, "must include at least one special character (!@#$%^&*)" unless password.match?(/[!@#$%^&*]/)
  end
end
