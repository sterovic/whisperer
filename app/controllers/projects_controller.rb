class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy, :switch]

  def index
    @projects = policy_scope(Project).order(:name)
  end

  def show
    authorize @project
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

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
    authorize @project
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to root_path, notice: "Project updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy

    # If deleted project was current, switch to another
    if current_user.current_project_id == @project.id
      current_user.current_project = current_user.projects.first
    end

    redirect_to root_path, notice: "Project deleted successfully"
  end

  def switch
    authorize @project
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
