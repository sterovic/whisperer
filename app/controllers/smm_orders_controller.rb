class SmmOrdersController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  def index
    @orders = SmmOrder.joins(:smm_panel_credential)
                      .where(smm_panel_credentials: { user_id: current_user.id })
                      .for_project(@current_project)
                      .recent
                      .includes(:smm_panel_credential, :video)
                      .page(params[:page])
                      .per(25)
  end
end