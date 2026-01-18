class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :switch]

  def index
    @projects = current_user.projects.order(:name)
  end

  def show
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      # Create project membership for current user
      current_user.project_members.create!(project: @project)
      # Set as current project
      current_user.current_project = @project

      redirect_to root_path, notice: "Project created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to root_path, notice: "Project updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy

    # If deleted project was current, switch to another
    if current_user.current_project_id == @project.id
      current_user.current_project = current_user.projects.first
    end

    redirect_to root_path, notice: "Project deleted successfully"
  end

  def switch
    current_user.current_project = @project
    redirect_to root_path, notice: "Switched to #{@project.name}"
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
