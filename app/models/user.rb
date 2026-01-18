class User < ApplicationRecord
  has_many :project_members, dependent: :destroy
  has_many :projects, through: :project_members
  has_many :google_accounts, dependent: :destroy

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
                 :current_project_id

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

  private

  def password_complexity
    return if password.blank?

    errors.add :password, "must include at least one lowercase letter" unless password.match?(/[a-z]/)
    errors.add :password, "must include at least one uppercase letter" unless password.match?(/[A-Z]/)
    errors.add :password, "must include at least one digit" unless password.match?(/\d/)
    errors.add :password, "must include at least one special character (!@#$%^&*)" unless password.match?(/[!@#$%^&*]/)
  end
end
