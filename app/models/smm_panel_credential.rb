class SmmPanelCredential < ApplicationRecord
  belongs_to :user
  has_many :smm_orders, dependent: :destroy

  encrypts :api_key

  validates :panel_type, presence: true
  validates :api_key, presence: true
  validates :panel_type, uniqueness: { scope: :user_id, message: "already configured for this user" }

  PANEL_TYPES = %w[jap].freeze

  validates :panel_type, inclusion: { in: PANEL_TYPES }

  def adapter
    @adapter ||= case panel_type
    when "jap"
      SmmAdapters::JapAdapter.new(api_key)
    else
      raise "Unknown panel type: #{panel_type}"
    end
  end

  def display_name
    case panel_type
    when "jap"
      "Just Another Panel"
    else
      panel_type.titleize
    end
  end
end