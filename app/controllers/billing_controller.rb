class BillingController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    if params[:session_id].present?
      session = Stripe::Checkout::Session.retrieve(params[:session_id])
      plan = Plan.find_by(id: session.metadata["plan_id"])
      flash.now[:notice] = "You're now on the #{plan&.name || 'new'} plan!"
    end

    @plans = Plan.ordered
    @current_plan = current_user.current_plan
    @subscription = current_user.active_subscription
    @usage = {
      projects: current_user.total_projects_count,
      videos: current_user.total_videos_count,
      comments: current_user.total_comments_count,
      google_accounts: current_user.total_google_accounts_count
    }

    # Fetch Stripe subscription & invoice details
    if @subscription&.stripe_customer_id.present?
      @invoices = Stripe::Invoice.list(customer: @subscription.stripe_customer_id, limit: 10).data
      if @subscription.stripe_subscription_id.present?
        @stripe_subscription = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
      end
    else
      @invoices = []
    end
  end

  def checkout
    plan = Plan.find(params[:plan_id])
    billing_cycle = params[:billing_cycle] || "monthly"

    price_id = billing_cycle == "yearly" ? plan.stripe_yearly_price_id : plan.stripe_monthly_price_id

    if price_id.blank?
      redirect_to billing_path, alert: "This plan is not available for purchase yet."
      return
    end

    # Find or create Stripe customer
    customer_id = current_user.active_subscription&.stripe_customer_id
    unless customer_id
      customer = Stripe::Customer.create(email: current_user.email, metadata: { user_id: current_user.id })
      customer_id = customer.id
    end

    session = Stripe::Checkout::Session.create(
      customer: customer_id,
      mode: "subscription",
      line_items: [{ price: price_id, quantity: 1 }],
      success_url: billing_url + "?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: billing_url,
      metadata: { user_id: current_user.id, plan_id: plan.id, billing_cycle: billing_cycle }
    )

    redirect_to session.url, allow_other_host: true
  end

  def portal
    customer_id = current_user.active_subscription&.stripe_customer_id

    unless customer_id
      redirect_to billing_path, alert: "No active subscription found."
      return
    end

    session = Stripe::BillingPortal::Session.create(
      customer: customer_id,
      return_url: billing_url
    )

    redirect_to session.url, allow_other_host: true
  end
end
