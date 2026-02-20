class CommentsController < ApplicationController
  include CommentAuthorHelper

  before_action :authenticate_user!
  before_action :set_comment, only: [:reply_form, :reply, :upvote]

  def index
    policy_scope(Comment)
    return if current_project.nil?

    @has_comments = current_project.comments.top_level.exists?

    scope = current_project.comments
                           .top_level
                           .includes(:video, :google_account, :replies, :snapshots)

    scope = filter_comments(scope)
    scope = sort_comments(scope)

    @comments = scope.page(params[:page]).per(20)
    @videos = current_project.videos.order(:title)
    @channels = current_project.channels.order(:name)
    @status_check_schedule = JobSchedule.find_by(job_class: "CommentStatusCheckJob", project_id: current_project&.id)
  end

  def reply_form
    authorize @comment, :reply?
    @google_accounts = current_user.google_accounts.excluding(@comment.google_account).usable
    @max_replies = @google_accounts.count

    render partial: "comments/reply_modal",
           locals: {
             comment: @comment,
             google_accounts: @google_accounts,
             max_replies: @max_replies
           }
  end

  def reply
    authorize @comment, :reply?
    num_replies = params[:num_replies].to_i
    account_ids = params[:account_ids] || []
    random_selection = params[:random_selection] == "1"

    if num_replies < 1
      redirect_to comments_path, alert: "Please select at least 1 reply"
      return
    end

    usable_accounts = current_user.google_accounts.usable
    if usable_accounts.empty?
      redirect_to comments_path, alert: "No usable Google accounts available"
      return
    end

    # Cap at available accounts
    max_replies = usable_accounts.count
    num_replies = [num_replies, max_replies].min

    job = CommentReplyJob.perform_later(
      current_user.id,
      @comment.id,
      {
        num_replies: num_replies,
        account_ids: random_selection ? [] : account_ids,
        random_selection: random_selection
      }
    )

    @job_id = job.job_id
    @num_replies = num_replies

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to comments_path, notice: "Reply job started. #{num_replies} reply(ies) will be posted."
      end
    end
  end

  def upvote
    authorize @comment
    quantity = params[:quantity].to_i

    if quantity < 1
      redirect_to comments_path(request.query_parameters), alert: "Quantity must be at least 1"
      return
    end

    credential = current_user.smm_panel_credentials.find_by(panel_type: "jap")
    unless credential&.upvote_service_id.present?
      redirect_to comments_path(request.query_parameters), alert: "JAP panel not configured or upvote service not set"
      return
    end

    comment_url = "https://www.youtube.com/watch?v=#{@comment.video.youtube_id}&lc=#{@comment.youtube_comment_id}"
    result = credential.adapter.upvote_comment(
      comment_url: comment_url,
      quantity: quantity,
      service_id: credential.upvote_service_id
    )

    if result[:success]
      SmmOrder.create!(
        smm_panel_credential: credential,
        project: current_project,
        video: @comment.video,
        comment: @comment,
        external_order_id: result[:order_id],
        service_type: :upvote,
        status: :pending,
        quantity: quantity,
        link: comment_url
      )
      redirect_to comments_path(request.query_parameters), notice: "Upvote order placed! #{quantity} likes ordered."
    else
      redirect_to comments_path(request.query_parameters), alert: "SMM Panel error: #{result[:error]}"
    end
  rescue SmmAdapters::BaseAdapter::ApiError => e
    redirect_to comments_path(request.query_parameters), alert: "SMM Panel error: #{e.message}"
  end

  private

  def set_comment
    @comment = current_project.comments.find(params[:id])
  end

  def current_project
    current_user.current_project
  end

  def any_filters_active?
    params[:appearance].present? || params[:source].present? || params[:video_id].present? ||
      params[:channel_id].present? || params[:q].present? || params[:replies].present? ||
      (params[:sort].present? && params[:sort] != "newest")
  end

  helper_method :current_project, :any_filters_active?

  def filter_comments(scope)
    scope = scope.where(appearance: params[:appearance]) if params[:appearance].present? && Comment.appearances.key?(params[:appearance])
    scope = scope.where(post_type: params[:source]) if params[:source].present? && Comment.post_types.key?(params[:source])
    scope = scope.where(video_id: params[:video_id]) if params[:video_id].present?
    scope = scope.joins(video: :channel).where(channels: { id: params[:channel_id] }) if params[:channel_id].present?

    if params[:q].present?
      scope = scope.where("comments.text ILIKE ?", "%#{Comment.sanitize_sql_like(params[:q])}%")
    end

    case params[:replies]
    when "with"
      scope = scope.where("EXISTS (SELECT 1 FROM comments r WHERE r.parent_id = comments.id)")
    when "without"
      scope = scope.where("NOT EXISTS (SELECT 1 FROM comments r WHERE r.parent_id = comments.id)")
    end

    scope
  end

  def sort_comments(scope)
    case params[:sort]
    when "oldest"
      scope.order(created_at: :asc)
    when "likes"
      scope.order(like_count: :desc, created_at: :desc)
    when "reach"
      scope.order(total_reach: :desc, created_at: :desc)
    when "rank"
      scope.order(Arel.sql("comments.rank ASC NULLS LAST"), created_at: :desc)
    else
      scope.order(created_at: :desc)
    end
  end
end