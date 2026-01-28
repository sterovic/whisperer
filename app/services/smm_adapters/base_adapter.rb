module SmmAdapters
  class BaseAdapter
    class ApiError < StandardError; end
    class AuthenticationError < ApiError; end
    class InvalidServiceError < ApiError; end
    class InsufficientFundsError < ApiError; end

    def initialize(api_key)
      @api_key = api_key
    end

    # Post multiple comments to a video
    # @param video_url [String] The YouTube video URL
    # @param comments [Array<String>] Array of comment texts
    # @param service_id [String] The service ID to use
    # @return [Hash] { order_id: String, success: Boolean, error: String? }
    def bulk_comment(video_url:, comments:, service_id:)
      raise NotImplementedError, "#{self.class} must implement #bulk_comment"
    end

    # Upvote a comment
    # @param comment_url [String] The YouTube comment URL
    # @param quantity [Integer] Number of upvotes
    # @param service_id [String] The service ID to use
    # @return [Hash] { order_id: String, success: Boolean, error: String? }
    def upvote_comment(comment_url:, quantity:, service_id:)
      raise NotImplementedError, "#{self.class} must implement #upvote_comment"
    end

    # Check status of a single order
    # @param order_id [String] The order ID
    # @return [Hash] { charge: Decimal, start_count: Integer, status: String, remains: Integer, currency: String }
    def check_order_status(order_id:)
      raise NotImplementedError, "#{self.class} must implement #check_order_status"
    end

    # Check status of multiple orders (batch)
    # @param order_ids [Array<String>] Array of order IDs
    # @return [Hash<String, Hash>] Map of order_id => status hash
    def check_orders_status(order_ids:)
      raise NotImplementedError, "#{self.class} must implement #check_orders_status"
    end

    # Get account balance
    # @return [Hash] { balance: Decimal, currency: String }
    def get_balance
      raise NotImplementedError, "#{self.class} must implement #get_balance"
    end

    # Get available services
    # @return [Array<Hash>] Array of service hashes with id, name, rate, min, max, etc.
    def get_services
      raise NotImplementedError, "#{self.class} must implement #get_services"
    end

    protected

    attr_reader :api_key
  end
end