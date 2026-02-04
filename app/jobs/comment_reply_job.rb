class CommentReplyJob < ApplicationJob
  queue_as :default

  def perform(user_id, comment_id, options = {})
    options = options.symbolize_keys
    @user = User.find(user_id)
    @comment = Comment.find(comment_id)
    @project = @comment.project
    @video = @comment.video
    @job_id = provider_job_id || job_id

    # Parse options
    num_replies = options[:num_replies] || 1
    account_ids = options[:account_ids] || []
    random_selection = options[:random_selection] || false

    # Get accounts to use
    @accounts = if random_selection
                  @user.google_accounts.usable.order("RANDOM()").limit(num_replies)
                else
                  @user.google_accounts.usable.where(id: account_ids)
                end

    if @accounts.empty?
      broadcast_error("No usable Google accounts available")
      return
    end

    # Limit replies to number of available accounts
    num_replies = [num_replies, @accounts.count].min
    @total_steps = num_replies
    @current_step = 0

    begin
      broadcast_progress("Generating #{num_replies} reply(ies)...")

      # Generate replies
      replies = generate_replies(num_replies)

      if replies.blank? || replies.empty?
        broadcast_error("Could not generate replies")
        return
      end

      broadcast_progress("Generated #{replies.count} reply(ies). Posting...")

      # Post each reply with a different account
      posted_count = 0
      replies.each_with_index do |reply_text, index|
        break if index >= @accounts.count

        @current_step = index + 1
        account = @accounts[index]

        broadcast_progress("Posting reply #{index + 1}/#{num_replies} as #{account.display_name}...")

        if post_reply(account, reply_text)
          posted_count += 1
        end

        sleep 2 if index < replies.count - 1 # Rate limiting between posts
      end

      broadcast_completion(success: true, message: "Posted #{posted_count} reply(ies)")
    rescue StandardError => e
      Rails.logger.error "CommentReplyJob error: #{e.message}\n#{e.backtrace.join("\n")}"
      broadcast_error(e.message)
      raise
    end
  end

  private

  def generate_replies(num_replies)
    generator = ReplyGenerator.new
    generator.generate_replies(
      project: @project,
      comment: @comment,
      video: @video,
      num_replies: num_replies
    )
  rescue => e
    Rails.logger.error "Error generating replies: #{e.message}"
    nil
  end

  def post_reply(account, reply_text)
    yt_account = account.yt_account
    yt_response = yt_account.comments.insert(parent_id: @comment.youtube_comment_id, text: reply_text)

    youtube_reply_id = yt_response.id rescue nil

    Comment.create!(
      text: reply_text,
      video: @video,
      google_account: account,
      project: @project,
      parent: @comment,
      youtube_comment_id: youtube_reply_id,
      status: :visible,
      author_display_name: yt_response.author_display_name,
      author_avatar_url: yt_response.author_profile_image_url,
      post_type: :via_api
    )

    true
  rescue GoogleAccount::TokenNotUsableError => e
    Rails.logger.warn "Account token not usable: #{e.message}"
    broadcast_progress("Account #{account.display_name} token is not usable, skipping...")
    false
  rescue Yt::Errors::Unauthorized => e
    Rails.logger.warn "Account unauthorized: #{e.message}"
    account.mark_as_unauthorized!
    broadcast_progress("Account #{account.display_name} authorization expired")
    false
  rescue Yt::Errors::Forbidden => e
    Rails.logger.warn "Cannot post reply (forbidden): #{e.message}"
    broadcast_progress("Could not post reply: access denied")
    false
  rescue Yt::Errors::RequestError => e
    Rails.logger.warn "Cannot post reply: #{e.message}"
    broadcast_progress("Could not post reply: #{e.message.truncate(50)}")
    false
  end

  def broadcast_progress(message)
    progress_percentage = @total_steps.positive? ? (@current_step.to_f / @total_steps * 100).to_i : 0

    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Reply Posting",
        message: message,
        percentage: progress_percentage,
        status: :running
      }
    )
  end

  def broadcast_completion(success:, message:)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Reply Posting",
        message: message,
        percentage: 100,
        status: success ? :completed : :failed
      }
    )
  end

  def broadcast_error(error_message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        job_name: "Reply Posting",
        message: "Error: #{error_message}",
        percentage: 0,
        status: :failed
      }
    )
  end
end
