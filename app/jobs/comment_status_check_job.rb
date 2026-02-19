class CommentStatusCheckJob < ScheduledJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default

  good_job_control_concurrency_with(
    perform_limit: 1,
    key: -> { "#{self.class.name}-#{arguments.second}" }
  )

  self.job_display_name = "Comment Status Check"

  private

  def execute(options)
    # Check top-level visible comments for this project
    visible_comments = @project.comments.top_level.visible.includes(:video, :project, :replies)
    Rails.logger.info "CommentStatusCheckJob: Checking #{visible_comments.count} visible top-level comments"

    visible_comments.find_each do |comment|
      check_comment_status(comment)
    rescue StandardError => e
      Rails.logger.error "Error checking comment #{comment.id}: #{e.message}"
    end

    # Check our own replies (replies we posted) for this project
    our_replies = @project.comments.where.not(parent_id: nil).visible.includes(:video, :project, :parent)
    Rails.logger.info "CommentStatusCheckJob: Checking #{our_replies.count} visible replies"

    our_replies.find_each do |reply|
      check_reply_status(reply)
    rescue StandardError => e
      Rails.logger.error "Error checking reply #{reply.id}: #{e.message}"
    end
  end

  def check_comment_status(comment)
    return unless comment.youtube_comment_id.present? && comment.video.present?

    video = comment.video
    yt_video = Yt::Video.new(id: video.youtube_id)

    # Try calling some method on a Yt::CommentThread to trigger the API call
    # If no items are returned, the comment doesn't exist - it's been removed
    yt_comment = Yt::CommentThread.new(id: comment.youtube_comment_id)
    yt_comment.text_display

    # Check if the comment is visible in the video's top comments
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
      comment.record_snapshot!(rank: rank, like_count: yt_comment.like_count || 0, video_views: yt_video.view_count || 0)
      import_replies(comment, yt_comment)
    else
      comment.update!(status: :hidden, rank: nil)
    end
  rescue Yt::Errors::NoItems => e
    comment.update!(status: :removed, rank: nil)
  end

  def check_reply_status(reply)
    return unless reply.youtube_comment_id.present? && reply.video.present?

    # Try to fetch the reply directly using the YouTube API
    # Replies use Yt::Comment, not Yt::CommentThread
    begin
      yt_reply = Yt::Comment.new(id: reply.youtube_comment_id)
      yt_reply.text_display # Trigger API call

      # Update like count if still accessible
      reply.update!(like_count: yt_reply.like_count || 0, status: :visible)
    rescue Yt::Errors::NoItems
      # Reply was removed
      reply.update!(status: :removed)
    rescue Yt::Errors::Forbidden
      # Reply may be hidden or inaccessible
      reply.update!(status: :hidden)
    end
  end

  def import_replies(comment, yt_comment_thread)
    return unless comment.youtube_comment_id.present?

    begin
      # Fetch replies for this comment thread
      replies = yt_comment_thread.replies
      return if replies.blank?

      existing_reply_ids = comment.replies.pluck(:youtube_comment_id).compact.to_set
      imported_count = 0

      replies.each do |yt_reply|
        next if existing_reply_ids.include?(yt_reply.id)

        begin
          Comment.create!(
            video: comment.video,
            project: comment.project,
            parent: comment,
            youtube_comment_id: yt_reply.id,
            text: yt_reply.text_display,
            author_display_name: yt_reply.author_display_name,
            author_avatar_url: yt_reply.author_profile_image_url,
            like_count: yt_reply.like_count || 0,
            status: :visible,
            post_type: :manual
          )
          imported_count += 1
        rescue ActiveRecord::RecordNotUnique
          # Already imported by another concurrent run
        end
      end

      Rails.logger.info "Imported #{imported_count} replies for comment #{comment.id}" if imported_count > 0
    rescue Yt::Errors::Forbidden => e
      Rails.logger.warn "Cannot fetch replies for comment #{comment.id}: #{e.message}"
    rescue Yt::Errors::RequestError => e
      Rails.logger.warn "Error fetching replies for comment #{comment.id}: #{e.message}"
    end
  end
end
