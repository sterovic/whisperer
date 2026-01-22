class Project < ApplicationRecord
  has_many :project_members, dependent: :destroy
  has_many :users, through: :project_members
  has_many :videos, dependent: :destroy
  has_many :comments, dependent: :destroy

  validates :name, presence: true

  # Prompt settings stored in JSONB column
  store_accessor :prompt_settings,
                 :additional_instructions,
                 :comment_length,
                 :tone,
                 :temperature,
                 :model,
                 :max_tokens,
                 :include_video_title,
                 :include_video_description,
                 :include_existing_comments,
                 :mention_product,
                 :num_comments

  # Default values for prompt settings
  PROMPT_DEFAULTS = {
    additional_instructions: nil,
    comment_length: "medium",
    tone: "casual",
    temperature: 0.9,
    model: "gpt-4o-mini",
    max_tokens: 1000,
    include_video_title: true,
    include_video_description: true,
    include_existing_comments: true,
    mention_product: true,
    num_comments: 10
  }.freeze

  COMMENT_LENGTHS = %w[short medium long].freeze
  TONES = %w[casual friendly enthusiastic professional witty sarcastic].freeze
  MODELS = %w[gpt-4o-mini gpt-4o gpt-4-turbo].freeze

  def prompt_setting(key)
    value = send(key)
    return PROMPT_DEFAULTS[key.to_sym] if value.nil? || value == ""

    # Handle boolean conversions from form
    case PROMPT_DEFAULTS[key.to_sym]
    when true, false
      ActiveModel::Type::Boolean.new.cast(value)
    when Integer
      value.to_i
    when Float
      value.to_f
    else
      value
    end
  end
end