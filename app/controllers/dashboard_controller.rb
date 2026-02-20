class DashboardController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  helper DashboardHelper
  layout "dashboard"

  def index
  end
end
