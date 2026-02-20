class Plan < ApplicationRecord
  has_many :subscriptions

  scope :ordered, -> { order(:price_monthly_cents) }
  scope :paid, -> { where.not(slug: "free") }

  def self.free
    find_by(slug: "free")
  end

  def free?
    slug == "free"
  end

  def unlimited?(resource)
    limit_for(resource).nil?
  end

  def limit_for(resource)
    send(:"max_#{resource}")
  end
end
