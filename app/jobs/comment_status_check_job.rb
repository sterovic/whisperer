class CommentStatusCheckJob < ApplicationJob
  queue_as :default

  after_perform do |job|
    # reschedule job if enabled
    schedule = JobSchedule.for(job.class.name)
    job.class.set(wait: schedule.interval_minutes.minutes).perform_later if schedule.enabled?
  end

  def perform
    schedule = JobSchedule.for(self.class.name)

    # Skip if another instance already ran recently (prevents duplicates when interval changes)
    if schedule.recently_ran?
      Rails.logger.info "CommentStatusCheckJob: Skipping - another instance ran recently"
      return
    end

    schedule.touch(:last_run_at)

    visible_comments = Comment.top_level.visible.includes(:video, :project)
    return if visible_comments.empty?

    Rails.logger.info "CommentStatusCheckJob: Checking #{visible_comments.count} visible comments"

    visible_comments.find_each do |comment|
      check_comment_status(comment)
    rescue StandardError => e
      Rails.logger.error "Error checking comment #{comment.id}: #{e.message}"
    end
  end

  private

  def check_comment_status(comment)
    return unless comment.youtube_comment_id.present? && comment.video.present?

    video = comment.video
    yt_video = Yt::Video.new(id: video.youtube_id)

    # Fetch top-level comments from the video
    video_comments = fetch_video_comments(yt_video)

    # Check if our comment is in the fetched comments
    found_comment = video_comments.find { |yt_comment| yt_comment.id == comment.youtube_comment_id }

    if found_comment
      # Comment is visible in the video's comment list
      update_comment_from_yt(comment, found_comment, video_comments)
      comment.visible! unless comment.visible?
    elsif comment_exists_directly?(comment.youtube_comment_id)
      # Comment exists but not in the top comments list (hidden from top)
      comment.hidden! unless comment.hidden?
      Rails.logger.info "Comment #{comment.id} is hidden from top"
    else
      # Comment doesn't exist at all (removed)
      comment.removed! unless comment.removed?
      Rails.logger.info "Comment #{comment.id} has been removed"
    end
  end

  def fetch_video_comments(yt_video)
    yt_video.comment_threads.where(order: :relevance).take(9999)
  rescue Yt::Errors::Forbidden, Yt::Errors::RequestError
    Rails.logger.warn "Cannot fetch comments for video: #{yt_video.id}"
    []
  end

  def comment_exists_directly?(youtube_comment_id)
    # Try to fetch the comment thread directly by ID
    comment_thread = Yt::CommentThread.new(id: youtube_comment_id)
    # Try to access a property to trigger the API call
    comment_thread.text_display.present?
  rescue Yt::Errors::NoItems, Yt::Errors::Forbidden, Yt::Errors::RequestError
    false
  end

  def update_comment_from_yt(comment, yt_comment, all_comments)
    # Find rank (position in the list)
    rank = all_comments.index { |c| c.id == comment.youtube_comment_id }

    # Update like count and rank
    comment.update(
      like_count: yt_comment.like_count || 0,
      rank: rank ? rank + 1 : nil
    )
  end
end