class Video < ApplicationRecord
  belongs_to :project
  has_many :comments, dependent: :destroy

  validates :youtube_id, presence: true
  validates :youtube_id, uniqueness: { scope: :project_id, message: "already exists in this project" }

  scope :recently_fetched, -> { where("fetched_at > ?", 1.day.ago) }
  scope :needs_refresh, -> { where("fetched_at IS NULL OR fetched_at < ?", 1.week.ago) }

  # Extract YouTube video ID from various URL formats
  # Supports: youtube.com/watch?v=ID, youtu.be/ID, youtube.com/embed/ID, etc.
  def self.extract_youtube_id(url)
    return nil if url.blank?

    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/|youtube\.com\/v\/)([a-zA-Z0-9_-]{11})/,
      /^([a-zA-Z0-9_-]{11})$/ # Raw video ID
    ]

    patterns.each do |pattern|
      match = url.strip.match(pattern)
      return match[1] if match
    end

    nil
  end
end
