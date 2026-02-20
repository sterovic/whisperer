module Channels
  class SubscriptionsController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    before_action :set_project

    def index
      @channel_subscriptions = @project.channel_subscriptions.order(created_at: :desc)
    end

    def new
      @new_subscription = @project.channel_subscriptions.build
      @known_channels = load_known_channels
    end

    def create
      initial_import_limit = params[:channel_subscription][:initial_import_limit].presence&.to_i || 3
      channel_ids = collect_channel_ids

      if channel_ids.empty?
        redirect_to new_channels_subscription_path,
                    alert: "No valid channel IDs provided. Please select a channel or enter a channel ID (starting with UC)."
        return
      end

      created = 0
      errors = []

      channel_ids.each do |channel_id|
        subscription = @project.channel_subscriptions.build(
          channel_id: channel_id,
          initial_import_limit: initial_import_limit,
          status: :pending
        )

        if subscription.save
          YouTubeChannelSubscribeJob.perform_later(subscription.id)
          created += 1
        else
          errors << subscription.errors.full_messages.first
        end
      end

      if errors.any? && created == 0
        redirect_to new_channels_subscription_path, alert: errors.first
      elsif errors.any?
        redirect_to channels_subscriptions_path,
                    notice: "#{created} #{"subscription".pluralize(created)} created. Some failed: #{errors.join(", ")}"
      else
        redirect_to channels_subscriptions_path,
                    notice: "#{created} channel #{"subscription".pluralize(created)} initiated. They will be activated shortly."
      end
    end

    def destroy
      @subscription = @project.channel_subscriptions.find(params[:id])
      @subscription.destroy

      redirect_to channels_subscriptions_path,
                  notice: "Channel subscription removed."
    end

    private

    def set_project
      @project = current_user.current_project
      redirect_to dashboard_path, alert: "Please select a project first." unless @project
    end

    def collect_channel_ids
      ids = []

      selected = params[:channel_subscription][:channel_ids]
      if selected.present?
        ids.concat(Array(selected).reject(&:blank?))
      end

      manual_input = params[:channel_subscription][:channel_id]
      if manual_input.present?
        extracted = ChannelSubscription.extract_channel_id(manual_input)
        ids << extracted if extracted.present?
      end

      ids.uniq
    end

    def load_known_channels
      subscribed_yt_ids = @project.channel_subscriptions.pluck(:channel_id)
      @project.channels
              .where.not(youtube_channel_id: subscribed_yt_ids)
              .order(:name)
    end
  end
end
