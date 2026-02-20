class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan

  enum :status, { active: 0, past_due: 1, canceled: 2, incomplete: 3, trialing: 4, unpaid: 5 }
  enum :billing_cycle, { monthly: 0, yearly: 1 }

  scope :current, -> { where(status: [ :active, :trialing, :past_due ]) }
end
