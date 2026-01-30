class CommentsController < ApplicationController
  include CommentAuthorHelper

  before_action :authenticate_user!
  before_action :set_comment, only: [:reply_form, :reply]

  def index
    @has_comments = current_project&.comments&.top_level&.exists?

    scope = current_project.comments
                           .top_level
                           .includes(:video, :google_account, :replies)

    scope = filter_comments(scope)
    scope = sort_comments(scope)

    @comments = scope.page(params[:page]).per(20)
    @videos = current_project.videos.order(:title)
    @status_check_schedule = JobSchedule.find_by(job_class: "CommentStatusCheckJob")
  end

  def reply_form
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

  private

  def set_comment
    @comment = current_project.comments.find(params[:id])
  end

  def current_project
    current_user.current_project
  end

  def any_filters_active?
    params[:status].present? || params[:source].present? || params[:video_id].present? ||
      params[:q].present? || params[:replies].present? || (params[:sort].present? && params[:sort] != "newest")
  end

  helper_method :current_project, :any_filters_active?

  def filter_comments(scope)
    scope = scope.where(status: params[:status]) if params[:status].present? && Comment.statuses.key?(params[:status])
    scope = scope.where(post_type: params[:source]) if params[:source].present? && Comment.post_types.key?(params[:source])
    scope = scope.where(video_id: params[:video_id]) if params[:video_id].present?

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
    when "rank"
      scope.order(Arel.sql("comments.rank ASC NULLS LAST"), created_at: :desc)
    else
      scope.order(created_at: :desc)
    end
  end
end