module Settings
  class ProjectController < ApplicationController
    before_action :set_project

    def show
      @smm_panel_credentials = current_user.smm_panel_credentials
    end

    def update
      if @project.update(project_params)
        redirect_to settings_project_path, notice: "Project settings saved successfully."
      else
        @smm_panel_credentials = current_user.smm_panel_credentials
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_project
      @project = @current_project
      redirect_to dashboard_path, alert: "Please select a project first." unless @project
    end

    def project_params
      params.require(:project).permit(
        :name,
        :description,
        :comment_method,
        :smm_panel_type
      )
    end
  end
end