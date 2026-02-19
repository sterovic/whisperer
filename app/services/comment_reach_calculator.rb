class CommentReachCalculator
  # ~20% of viewers engage with comments section
  BASE_ENGAGEMENT_RATE = 0.20

  # Position weights based on visibility
  # Top 3: Almost always visible without scrolling
  # 4-10: Usually visible, above the fold
  # 11-20: Requires minimal scrolling
  # 21+: Low visibility, most users won't see
  POSITION_WEIGHTS = [
    { range: 1..3, weight: 1.0 },
    { range: 4..10, weight: 0.6 },
    { range: 11..20, weight: 0.3 },
    { range: 21..50, weight: 0.05 },
  ].freeze

  MAX_TRACKED_POSITION = 50

  attr_reader :view_delta, :position

  def initialize(view_delta:, position:)
    @view_delta = view_delta
    @position = position
  end

  def calculate
    return 0 if position.nil?
    return 0 if position > MAX_TRACKED_POSITION
    return 0 if view_delta <= 0

    (view_delta * position_weight * BASE_ENGAGEMENT_RATE).round
  end

  # Breakdown for debugging/display
  def breakdown
    {
      view_delta: view_delta,
      position: position,
      position_weight: position_weight,
      engagement_rate: BASE_ENGAGEMENT_RATE,
      reach: calculate
    }
  end

  private

  def position_weight
    POSITION_WEIGHTS.find { |pw| pw[:range].include?(position) }&.fetch(:weight, 0) || 0
  end

  # Class method for convenience
  class << self
    def calculate(view_delta:, position:)
      new(view_delta: view_delta, position: position).calculate
    end
  end
end