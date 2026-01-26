module YouTubeErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from Yt::Errors::Unauthorized, with: :handle_youtube_unauthorized
    rescue_from GoogleAccount::TokenNotUsableError, with: :handle_token_not_usable
  end

  private

  def handle_youtube_unauthorized(exception)
    google_account = find_google_account_from_exception(exception)
    google_account&.mark_as_unauthorized!

    respond_to do |format|
      format.html do
        redirect_to google_accounts_path,
          alert: "YouTube authorization expired for #{google_account&.display_name || 'account'}. Please reconnect."
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.prepend("flash_messages",
          partial: "shared/flash_alert",
          locals: { message: "Authorization expired. Please reconnect your Google account." }
        )
      end
      format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
    end
  end

  def handle_token_not_usable(exception)
    respond_to do |format|
      format.html do
        redirect_to google_accounts_path,
          alert: "Google account token is not usable. Please reconnect the account."
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.prepend("flash_messages",
          partial: "shared/flash_alert",
          locals: { message: "Account token is not usable. Please reconnect." }
        )
      end
      format.json { render json: { error: "Token not usable" }, status: :unauthorized }
    end
  end

  def find_google_account_from_exception(exception)
    nil
  end
end
