class Video < ApplicationRecord
  belongs_to :project
  belongs_to :channel, optional: true
  has_many :comments, dependent: :destroy
  has_many :smm_orders, dependent: :nullify

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

  def popularity
  end

  def comment_frequency(period: 7.days)
    video = Yt::Video.new id: youtube_id
    period_start = Date.today - period
    all_comments = []
    page_token = nil

    loop do
      batch = video.comment_threads.take(100)
      batch = batch.page_token(page_token) if page_token

      comments = batch.to_a
      break if comments.empty?

      recent_comments = comments.select { |c| c.updated_at.to_date >= period_start }
      all_comments.concat(recent_comments)

      # Stop if we found comments older than period_start in this batch
      break if comments.any? { |c| c.updated_at.to_date < period_start }

      page_token = batch.next_page
      break unless page_token
    end

    comment_frequencies = all_comments.map { |c| c.updated_at.to_date }.tally

    (period_start..Date.today).index_with { |date| comment_frequencies[date] || 0 }
  end
end
