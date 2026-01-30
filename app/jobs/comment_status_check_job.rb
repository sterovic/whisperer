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

    # Try calling some method on a Yt::CommentThread to trigger the API call
    # If no items are returned, the comment doesn't exist - it's been removed
    yt_comment = Yt::CommentThread.new(id: comment.youtube_comment_id)
    yt_comment.text_display

    # Now let's check if the comment is visible in the video's comment list
    matched = false
    rank = 0
    yt_video.comment_threads.where(order: :relevance).each do |thread|
      rank += 1
      if thread.id == comment.youtube_comment_id
        matched = true
        break
      end
    end
    if matched
      comment.update!(like_count: yt_comment.like_count || 0, rank: rank, status: :visible)
    else
      comment.update!(status: :hidden, rank: nil)
    end
  rescue Yt::Errors::NoItems => e
    comment.update!(status: :removed, rank: nil)
  end
end
