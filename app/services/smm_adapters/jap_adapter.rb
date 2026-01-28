module SmmAdapters
  class JapAdapter < BaseAdapter
    BASE_URL = "https://justanotherpanel.com/api/v2".freeze

    # Post multiple comments to a video using custom comments service
    def bulk_comment(video_url:, comments:, service_id:)
      # JAP expects comments separated by \n
      comments_text = comments.join("\n")

      response = make_request(
        action: "add",
        service: service_id,
        link: video_url,
        comments: comments_text,
        quantity: comments.size
      )

      if response[:order]
        { order_id: response[:order].to_s, success: true }
      else
        { success: false, error: response[:error] || "Unknown error" }
      end
    end

    # Upvote a comment
    def upvote_comment(comment_url:, quantity:, service_id:)
      response = make_request(
        action: "add",
        service: service_id,
        link: comment_url,
        quantity: quantity
      )

      if response[:order]
        { order_id: response[:order].to_s, success: true }
      else
        { success: false, error: response[:error] || "Unknown error" }
      end
    end

    # Check status of a single order
    def check_order_status(order_id:)
      response = make_request(
        action: "status",
        order: order_id
      )

      parse_status_response(response)
    end

    # Check status of multiple orders (up to 100)
    def check_orders_status(order_ids:)
      return {} if order_ids.empty?

      # JAP supports up to 100 orders at once
      order_ids = order_ids.first(100)

      response = make_request(
        action: "status",
        orders: order_ids.join(",")
      )

      # Response is a hash keyed by order ID
      result = {}
      response.each do |order_id, status_data|
        next unless status_data.is_a?(Hash)
        result[order_id.to_s] = parse_status_response(status_data.with_indifferent_access)
      end
      result
    end

    # Get account balance
    def get_balance
      response = make_request(action: "balance")

      {
        balance: response[:balance].to_f,
        currency: response[:currency] || "USD"
      }
    end

    # Get available services
    def get_services
      response = make_request(action: "services")

      return [] unless response.is_a?(Array)

      response.map(&:with_indifferent_access).map do |service|
        {
          id: service[:service].to_s,
          name: service[:name],
          type: service[:type],
          category: service[:category],
          rate: service[:rate].to_f,
          min: service[:min].to_i,
          max: service[:max].to_i,
          refill: service[:refill],
          cancel: service[:cancel]
        }
      end
    end

    private

    def make_request(params)
      request_params = params.merge(key: api_key)

      # Log request as curl command for debugging
      log_curl_request(request_params)

      response = HTTP.headers("Content-Type": "application/json")
                     .post(BASE_URL, json: request_params)

      Rails.logger.info "[JAP] Response status: #{response.status}, content-type: #{response.content_type.mime_type}"

      unless response.status.success?
        raise ApiError, "HTTP Error: #{response.status}"
      end

      # Check content type before parsing
      content_type = response.content_type.mime_type
      unless content_type&.include?("json")
        # API returned HTML - likely an error page or invalid API key
        Rails.logger.error "[JAP] HTML response body: #{response.body.to_s.truncate(500)}"
        raise ApiError, "API returned invalid response (#{content_type}). Check your API key."
      end

      data = JSON.parse(response.body.to_s)
      Rails.logger.info "[JAP] Response data: #{data.to_json.truncate(500)}"

      # Handle both hash and array responses
      if data.is_a?(Hash)
        data = data.with_indifferent_access
        handle_api_error(data) if data[:error]
      end

      data
    rescue HTTP::Error => e
      raise ApiError, "Connection error: #{e.message}"
    rescue JSON::ParserError => e
      raise ApiError, "Invalid JSON response: #{e.message}"
    end

    def log_curl_request(params)
      # Mask API key for security
      masked_params = params.transform_values.with_index do |v, _|
        v
      end
      masked_params[:key] = "#{api_key[0..5]}...#{api_key[-4..]}" if api_key.present?

      form_data = masked_params.map { |k, v| "-d '#{k}=#{v}'" }.join(" \\\n  ")
      curl_cmd = "curl -X POST '#{BASE_URL}' \\\n  -H 'Accept: application/json' \\\n  #{form_data}"

      Rails.logger.info "[JAP] Request:\n#{curl_cmd}"
    end

    def handle_api_error(data)
      error = data[:error]

      case error
      when /invalid api key/i, /incorrect api key/i
        raise AuthenticationError, error
      when /insufficient funds/i, /not enough funds/i
        raise InsufficientFundsError, error
      when /invalid service/i, /service not found/i
        raise InvalidServiceError, error
      else
        raise ApiError, error
      end
    end

    def parse_status_response(data)
      {
        charge: data[:charge]&.to_f,
        start_count: data[:start_count]&.to_i,
        status: data[:status],
        remains: data[:remains]&.to_i,
        currency: data[:currency] || "USD"
      }
    end
  end
end
