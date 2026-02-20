namespace :stripe do
  desc "Sync plans from Stripe products/prices into the local database"
  task sync_plans: :environment do
    puts "Fetching products from Stripe..."

    products = Stripe::Product.list({ active: true, limit: 100 }).data
    synced_slugs = ["free"] # Free plan is managed locally, never deleted

    # Ensure the Free plan always exists
    free_plan = Plan.find_or_initialize_by(slug: "free")
    unless free_plan.persisted?
      free_plan.assign_attributes(
        name: "Free",
        price_monthly_cents: 0,
        price_yearly_cents: 0,
        max_projects: 1,
        max_videos: 1,
        max_comments: 10,
        max_google_accounts: 1,
        sort_order: 0
      )
      free_plan.save!
      puts "  Created Free plan (local-only, no Stripe product)"
    end

    products.each do |product|
      # Derive slug from product name (e.g. "Starter" → "starter"), or use metadata override
      slug = product.metadata["slug"].presence || product.name.parameterize

      # Fetch all active prices for this product
      prices = Stripe::Price.list({ product: product.id, active: true, limit: 100 }).data

      monthly_price = prices.find { |p| p.recurring&.interval == "month" }
      yearly_price = prices.find { |p| p.recurring&.interval == "year" }

      # Skip products that have no recurring prices (not a subscription plan)
      if monthly_price.nil? && yearly_price.nil?
        puts "  Skipping '#{product.name}' — no recurring prices found"
        next
      end

      plan = Plan.find_or_initialize_by(slug: slug)
      plan.assign_attributes(
        name: product.name,
        stripe_monthly_price_id: monthly_price&.id,
        stripe_yearly_price_id: yearly_price&.id,
        price_monthly_cents: monthly_price&.unit_amount || 0,
        price_yearly_cents: yearly_price&.unit_amount || 0,
        max_projects: parse_limit(product.metadata["max_projects"]),
        max_videos: parse_limit(product.metadata["max_videos"]),
        max_comments: parse_limit(product.metadata["max_comments"]),
        max_google_accounts: parse_limit(product.metadata["max_google_accounts"]),
        sort_order: (product.metadata["sort_order"] || 99).to_i
      )
      plan.save!

      synced_slugs << slug
      action = plan.previously_new_record? ? "Created" : "Updated"
      puts "  #{action} '#{plan.name}' — " \
             "monthly: #{format_cents(plan.price_monthly_cents)}, " \
             "yearly: #{format_cents(plan.price_yearly_cents)}, " \
             "limits: [P:#{plan.max_projects || '∞'} V:#{plan.max_videos || '∞'} " \
             "C:#{plan.max_comments || '∞'} G:#{plan.max_google_accounts || '∞'}]"
    end

    # Archive plans that no longer exist in Stripe
    stale_plans = Plan.where.not(slug: synced_slugs)
    if stale_plans.any?
      stale_plans.each do |plan|
        if plan.subscriptions.current.any?
          puts "  WARNING: '#{plan.name}' not in Stripe but has #{plan.subscriptions.current.count} active subscription(s) — skipping removal"
        else
          plan.destroy!
          puts "  Removed '#{plan.name}' (no longer in Stripe, no active subscriptions)"
        end
      end
    end

    puts "Done! #{Plan.count} plans in database."
  end
end

def parse_limit(value)
  return nil if value.blank? || value == "unlimited"
  value.to_i
end

def format_cents(cents)
  "$#{"%.2f" % (cents / 100.0)}"
end
