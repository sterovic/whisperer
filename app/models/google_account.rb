class GoogleAccount < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :nullify

  validates :google_id, presence: true
  validates :google_id, uniqueness: { scope: :user_id, message: "account already linked" }

  def display_name
    youtube_handle.presence || name.presence || email
  end

  def token_expired?
    token_expires_at.present? && token_expires_at < Time.current
  end

  def yt_account
    Yt::Account.new(refresh_token: refresh_token)
  end
end
