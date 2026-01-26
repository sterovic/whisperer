class GoogleAccount < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :nullify

  enum :token_status, { active: 0, revoked: 1, unauthorized: 2 }

  validates :google_id, presence: true
  validates :google_id, uniqueness: { scope: :user_id, message: "account already linked" }

  scope :usable, -> { where(token_status: :active) }

  def display_name
    youtube_handle.presence || name.presence || email
  end

  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def token_usable?
    active? && refresh_token.present?
  end

  def mark_as_unauthorized!
    update!(token_status: :unauthorized)
  end

  def mark_as_revoked!
    update!(token_status: :revoked, access_token: nil, refresh_token: nil)
  end

  def reactivate!
    update!(token_status: :active)
  end

  def yt_account
    raise TokenNotUsableError, "Token is not usable for account #{email}" unless token_usable?
    Yt::Account.new(refresh_token: refresh_token)
  end

  def yt_account!
    account = Yt::Account.new(refresh_token: refresh_token)
    account.access_token
    account
  rescue Yt::Errors::Unauthorized
    mark_as_invalid!
    raise
  end

  class TokenNotUsableError < StandardError; end
end
