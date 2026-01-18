class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  layout :determine_layout

  # Configure Devise permitted parameters
  before_action :configure_permitted_parameters, if: :devise_controller?

  before_action :authenticate_user!
  before_action :set_current_project

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end

  private

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
end
