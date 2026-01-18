# frozen_string_literal: true

Yt.configure do |config|
  config.api_key = Rails.application.credentials.dig(:youtube, :api_key)
  config.client_id = Rails.application.credentials.dig(:google, :client_id)
  config.client_secret = Rails.application.credentials.dig(:google, :client_secret)
  config.log_level = Rails.env.development? ? :devel : :debug
end
