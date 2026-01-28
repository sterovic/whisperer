class SmmOrderStatusCheckJob < ApplicationJob
  queue_as :default

  after_perform do |job|
    # Reschedule job if enabled
    schedule = JobSchedule.for(job.class.name)
    job.class.set(wait: schedule.interval_minutes.minutes).perform_later if schedule.enabled?
  end

  def perform
    schedule = JobSchedule.for(self.class.name)

    # Skip if another instance already ran recently (prevents duplicates when interval changes)
    if schedule.recently_ran?
      Rails.logger.info "SmmOrderStatusCheckJob: Skipping - another instance ran recently"
      return
    end

    schedule.touch(:last_run_at)

    uncompleted_orders = SmmOrder.uncompleted.includes(:smm_panel_credential)
    return if uncompleted_orders.empty?

    Rails.logger.info "SmmOrderStatusCheckJob: Checking #{uncompleted_orders.count} uncompleted orders"

    # Group orders by credential for efficient batch API calls
    orders_by_credential = uncompleted_orders.group_by(&:smm_panel_credential)

    orders_by_credential.each do |credential, orders|
      check_orders_for_credential(credential, orders)
    rescue StandardError => e
      Rails.logger.error "Error checking orders for credential #{credential.id}: #{e.message}"
    end
  end

  private

  def check_orders_for_credential(credential, orders)
    adapter = credential.adapter

    # Get external order IDs (skip orders without external IDs)
    order_ids = orders.filter_map(&:external_order_id)
    return if order_ids.empty?

    # Batch check status (JAP supports up to 100 at once)
    statuses = adapter.check_orders_status(order_ids: order_ids)

    orders.each do |order|
      next unless order.external_order_id
      status_data = statuses[order.external_order_id]
      next unless status_data

      update_order_status(order, status_data)
    rescue StandardError => e
      Rails.logger.error "Error updating order #{order.id}: #{e.message}"
    end
  end

  def update_order_status(order, status_data)
    previous_status = order.status

    order.update_from_api_response(status_data)

    if order.status != previous_status
      Rails.logger.info "SmmOrder #{order.id}: #{previous_status} -> #{order.status}"

      import_comments(order) if order.completed? && order.placed_for_comments?
    end
  end

  def import_comments(order)
    video = Video.find(order.video_id)
    yt_video = Yt::Video.new(id: video.youtube_id)
    existing_youtube_comments = Comment.where(video_id: video.id).pluck(:youtube_comment_id)
    comments = yt_video.comment_threads
                       .where(order: :time)
                       .map { |ct| {
                         id: ct.id,
                         text: ct.text_display,
                         author: ct.author_display_name,
                         image_url: ct.author_profile_image_url
                       } }
                       .select { |c| c[:text].include?(order.project.name) }
                       .reject { |c| c[:id].in?(existing_youtube_comments) }

    Comment.import!(comments, video, post_type: :via_smm) if comments.any?
  end
end
