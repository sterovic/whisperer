class PromptSettingsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :authenticate_user!
  before_action :require_current_project

  def show
    @project = current_project
    @videos = @project.videos.order(created_at: :desc).limit(20)
  end

  def update
    @project = current_project

    if @project.update(prompt_settings_params)
      redirect_to prompt_settings_path, notice: "Prompt settings saved successfully"
    else
      @videos = @project.videos.order(created_at: :desc).limit(20)
      render :show, status: :unprocessable_entity
    end
  end

  def test
    @project = current_project
    @video = @project.videos.find(params[:video_id])

    generator = CommentGenerator.new
    @comments = generator.generate_comments(
      project: @project,
      video: @video,
      num_comments: params[:num_comments]&.to_i || 3
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "test_results",
          partial: "prompt_settings/test_results",
          locals: { comments: @comments, video: @video }
        )
      end
      format.html { redirect_to prompt_settings_path }
    end
  rescue StandardError => e
    Rails.logger.error "Prompt test failed: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "test_results",
          partial: "prompt_settings/test_error",
          locals: { error: e.message }
        )
      end
      format.html { redirect_to prompt_settings_path, alert: "Test failed: #{e.message}" }
    end
  end

  private

  def require_current_project
    unless current_project
      redirect_to projects_path, alert: "Please select a project first"
    end
  end

  def current_project
    current_user.current_project
  end
  helper_method :current_project

  def prompt_settings_params
    params.require(:project).permit(
      :additional_instructions,
      :comment_length,
      :tone,
      :temperature,
      :model,
      :max_tokens,
      :include_video_title,
      :include_video_description,
      :include_existing_comments,
      :mention_product,
      :num_comments,
      :reply_prompt
    )
  end
end