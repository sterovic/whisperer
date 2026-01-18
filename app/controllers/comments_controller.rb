class CommentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @comments = current_project.comments
      .top_level
      .includes(:video, :google_account, :replies)
      .order(created_at: :desc)
      .page(params[:page])
      .per(20)

    @status_check_schedule = JobSchedule.find_by(job_class: "CommentStatusCheckJob")
  end

  private

  def current_project
    current_user.current_project
  end
  helper_method :current_project
end