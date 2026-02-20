# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

plans = [
  {
    name: "Free",
    slug: "free",
    price_monthly_cents: 0,
    price_yearly_cents: 0,
    stripe_monthly_price_id: nil,
    stripe_yearly_price_id: nil,
    max_projects: 1,
    max_videos: 1,
    max_comments: 10,
    max_google_accounts: 1,
    sort_order: 0
  },
  {
    name: "Starter",
    slug: "starter",
    price_monthly_cents: 4900,
    price_yearly_cents: 47_000,
    stripe_monthly_price_id: "price_starter_monthly_placeholder",
    stripe_yearly_price_id: "price_starter_yearly_placeholder",
    max_projects: 1,
    max_videos: 3,
    max_comments: 50,
    max_google_accounts: 1,
    sort_order: 1
  },
  {
    name: "Solo",
    slug: "solo",
    price_monthly_cents: 12_900,
    price_yearly_cents: 123_800,
    stripe_monthly_price_id: "price_solo_monthly_placeholder",
    stripe_yearly_price_id: "price_solo_yearly_placeholder",
    max_projects: 3,
    max_videos: 10,
    max_comments: 200,
    max_google_accounts: 3,
    sort_order: 2
  },
  {
    name: "Professional",
    slug: "professional",
    price_monthly_cents: 24_900,
    price_yearly_cents: 239_000,
    stripe_monthly_price_id: "price_professional_monthly_placeholder",
    stripe_yearly_price_id: "price_professional_yearly_placeholder",
    max_projects: 10,
    max_videos: 50,
    max_comments: 1000,
    max_google_accounts: 5,
    sort_order: 3
  },
  {
    name: "Ultimate",
    slug: "ultimate",
    price_monthly_cents: 39_900,
    price_yearly_cents: 383_000,
    stripe_monthly_price_id: "price_ultimate_monthly_placeholder",
    stripe_yearly_price_id: "price_ultimate_yearly_placeholder",
    max_projects: nil,
    max_videos: nil,
    max_comments: nil,
    max_google_accounts: 10,
    sort_order: 4
  }
]

plans.each do |plan_attrs|
  Plan.find_or_initialize_by(slug: plan_attrs[:slug]).tap do |plan|
    plan.assign_attributes(plan_attrs)
    plan.save!
  end
end

puts "Seeded #{Plan.count} plans"
