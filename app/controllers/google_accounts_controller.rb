class GoogleAccountsController < ApplicationController
  def index
    policy_scope(GoogleAccount)
    @google_accounts = current_user.google_accounts.order(created_at: :desc)
  end

  def connect
    authorize GoogleAccount, :connect?
    redirect_uri = oauth_callback_google_accounts_url
    scopes = %w[youtube.readonly youtube youtube.force-ssl userinfo.email userinfo.profile]

    auth_url = Yt::Account.new(scopes: scopes, redirect_uri: redirect_uri).authentication_url
    redirect_to auth_url, allow_other_host: true
  rescue Yt::Errors::MissingAuth => e
    Rails.logger.error "Google OAuth configuration error: #{e.message}"
    redirect_to google_accounts_path, alert: "Google OAuth is not configured. Please check client_id and client_secret."
  end

  def oauth_callback
    authorize GoogleAccount, :connect?
    if params[:error].present?
      puts params[:error]
      redirect_to google_accounts_path, alert: "Authorization failed: #{params[:error]}"
      return
    end

    redirect_uri = oauth_callback_google_accounts_url
    auth = Yt::Account.new(authorization_code: params[:code], redirect_uri: redirect_uri)

    response = HTTP.get("https://www.googleapis.com/oauth2/v1/userinfo?alt=json&access_token=#{auth.access_token}")
    account = response.parse.with_indifferent_access # Auto-parse JSON

    google_account = current_user.google_accounts.find_or_initialize_by(google_id: account[:id])

    is_new = google_account.new_record?
    google_account.assign_attributes(
      email: account[:email],
      name: account[:name],
      avatar_url: account[:picture],
      access_token: auth.access_token,
      refresh_token: auth.refresh_token,
      token_status: :active,
      token_expires_at: auth.expires_at,
      **timestamp_attrs(is_new)
    )
    google_account.save!

    redirect_to google_accounts_path, notice: "Google account connected successfully!"
  rescue Yt::Errors::Unauthorized, Yt::Errors::Forbidden => e
    puts "No valid authorization"
    redirect_to google_accounts_path, alert: "Authorization failed: #{e.message}"
  rescue Yt::Errors::RequestError => e
    Rails.logger.error "Google API error: #{e.message}"
    redirect_to google_accounts_path, alert: "Google API error: #{e.message}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to google_accounts_path, alert: "Could not save account: #{e.message}"
  end

  def disconnect
    @google_account = current_user.google_accounts.find(params[:id])
    authorize @google_account, :destroy?

    # Prefer refresh_token for revocation (access_token likely expired)
    revoke_token = @google_account.refresh_token.presence || @google_account.access_token.presence
    if revoke_token
      response = HTTP.post("https://accounts.google.com/o/oauth2/revoke?token=#{revoke_token}")
      Rails.logger.info "Google revoke response: #{response.code}"
    end

    @google_account.mark_as_revoked!
    redirect_to google_accounts_path, notice: "Google account disconnected."
  rescue ActiveRecord::RecordNotFound
    redirect_to google_accounts_path, alert: "Account not found."
  end

  private

  def timestamp_attrs(is_new)
    if is_new
      { authorized_at: Time.current }
    else
      { reauthorized_at: Time.current }
    end
  end

  def fetch_channel_id(account)
    account&.channel&.id
  rescue Yt::Errors::RequestError
    nil
  end

  def fetch_channel_handle(account)
    account&.channel&.username
  rescue Yt::Errors::RequestError
    nil
  end
end
