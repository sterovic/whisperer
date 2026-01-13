class Users::SessionsController < Devise::SessionsController
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    yield if block_given?
    redirect_to after_sign_out_path_for(resource_name), status: :see_other
  end
end