module Webhooks
  class StripeController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :set_current_project
    skip_before_action :set_new_channel_videos_count
    skip_before_action :verify_authenticity_token
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      webhook_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

      begin
        event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      rescue JSON::ParserError
        head :bad_request and return
      rescue Stripe::SignatureVerificationError
        head :bad_request and return
      end

      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "customer.subscription.updated"
        handle_subscription_updated(event.data.object)
      when "customer.subscription.deleted"
        handle_subscription_deleted(event.data.object)
      when "invoice.payment_failed"
        handle_payment_failed(event.data.object)
      end

      head :ok
    end

    private

    def handle_checkout_completed(session)
      user = User.find_by(id: session.metadata["user_id"])
      return unless user

      plan = Plan.find_by(id: session.metadata["plan_id"])
      return unless plan

      stripe_sub = Stripe::Subscription.retrieve(session.subscription)

      user.subscriptions.create!(
        plan: plan,
        stripe_subscription_id: stripe_sub.id,
        stripe_customer_id: session.customer,
        status: :active,
        billing_cycle: session.metadata["billing_cycle"] == "yearly" ? :yearly : :monthly,
        current_period_start: Time.at(stripe_sub.current_period_start),
        current_period_end: Time.at(stripe_sub.current_period_end)
      )
    end

    def handle_subscription_updated(stripe_sub)
      subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      return unless subscription

      status = case stripe_sub.status
               when "active" then :active
               when "past_due" then :past_due
               when "canceled" then :canceled
               when "incomplete" then :incomplete
               when "trialing" then :trialing
               when "unpaid" then :unpaid
               else :active
               end

      subscription.update!(
        status: status,
        current_period_start: Time.at(stripe_sub.current_period_start),
        current_period_end: Time.at(stripe_sub.current_period_end),
        canceled_at: stripe_sub.canceled_at ? Time.at(stripe_sub.canceled_at) : nil
      )
    end

    def handle_subscription_deleted(stripe_sub)
      subscription = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      return unless subscription

      subscription.update!(status: :canceled, canceled_at: Time.current)
    end

    def handle_payment_failed(invoice)
      subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
      return unless subscription

      subscription.update!(status: :past_due)
    end
  end
end
