module SmmPanels
  class JapController < ApplicationController
    before_action :set_credential, only: [:index, :update, :test_connection, :services]

    def index
      @orders = SmmOrder.joins(:smm_panel_credential)
                        .where(smm_panel_credentials: { user_id: current_user.id, panel_type: "jap" })
                        .for_project(@current_project)
                        .recent
                        .page(params[:page])
                        .per(20)
      @balance = fetch_balance if @credential&.persisted?
    end

    def update
      if @credential.update(credential_params)
        redirect_to smm_panels_jap_index_path, notice: "JAP settings saved successfully."
      else
        @orders = SmmOrder.none.page(1)
        render :index, status: :unprocessable_entity
      end
    end

    def test_connection
      if @credential.api_key.blank?
        redirect_to smm_panels_jap_index_path, alert: "Please enter an API key first."
        return
      end

      begin
        balance = @credential.adapter.get_balance
        redirect_to smm_panels_jap_index_path, notice: "Connection successful! Balance: #{balance[:balance]} #{balance[:currency]}"
      rescue SmmAdapters::BaseAdapter::AuthenticationError => e
        redirect_to smm_panels_jap_index_path, alert: "Authentication failed: #{e.message}"
      rescue SmmAdapters::BaseAdapter::ApiError => e
        redirect_to smm_panels_jap_index_path, alert: "API error: #{e.message}"
      end
    end

    def services
      if @credential.api_key.blank?
        @services = []
        @error = "Please configure your API key first."
        return
      end

      begin
        @services = @credential.adapter.get_services
      rescue SmmAdapters::BaseAdapter::ApiError => e
        @services = []
        @error = e.message
      end
    end

    private

    def set_credential
      @credential = current_user.smm_panel_credentials.find_or_initialize_by(panel_type: "jap")
    end

    def credential_params
      params.require(:smm_panel_credential).permit(:api_key, :comment_service_id, :upvote_service_id)
    end

    def fetch_balance
      @credential.adapter.get_balance
    rescue SmmAdapters::BaseAdapter::ApiError
      nil
    end
  end
end
