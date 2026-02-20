class ApplicationController < ActionController::Base
  include YouTubeErrorHandler
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  layout :determine_layout

  # Configure Devise permitted parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :authenticate_user!
  before_action :set_current_project
  before_action :set_new_channel_videos_count

  after_action :verify_authorized, unless: -> { skip_pundit? || action_name == "index" }
  after_action :verify_policy_scoped, if: -> { action_name == "index" && !skip_pundit? }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  private

  def user_not_authorized
    redirect_to(request.referrer || root_path, alert: "You've reached your plan limit. Upgrade to continue.")
  end

  def skip_pundit?
    devise_controller? || self.class == Rails::HealthController
  end

  def determine_layout
    if devise_edit_account_screen?
      "dashboard"
    elsif devise_controller?
      "auth"
    else
      "dashboard"
    end
  end

  def devise_edit_account_screen?
    controller_name == "registrations" && %w[edit update].include?(action_name)
  end

  def set_current_project
    return unless current_user

    @current_project = current_user.current_project || current_user.projects.first
    @other_projects = current_user.projects.where.not(id: @current_project&.id)

    # Auto-set current project if user has projects but none selected
    if @current_project && current_user.current_project_id.nil?
      current_user.update(current_project_id: @current_project.id)
    end
  end

  def set_new_channel_videos_count
    return unless current_user && @current_project

    last_viewed = current_user.videos_last_viewed_at
    scope = @current_project.videos.where("raw_data->>'source' = ?", "channel_poll")
    scope = scope.where("videos.created_at > ?", Time.parse(last_viewed)) if last_viewed.present?

    @new_channel_videos_count = scope.count
  end
end
