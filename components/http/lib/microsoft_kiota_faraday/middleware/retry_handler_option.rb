# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module MicrosoftKiotaFaraday
  module Middleware
    # Request option controlling {RetryHandler}'s retry budget, backoff delay and policy.
    class RetryHandlerOption
      include MicrosoftKiotaAbstractions::RequestOption

      MAX_RETRIES = 10
      MAX_DELAY = 180
      RETRYABLE_STATUS_CODES = [429, 503, 504].freeze
      # @return [Proc] the default retry policy: retries 429, 503 and 504 responses
      DEFAULT_SHOULD_RETRY = ->(_delay, _retries, response) { RETRYABLE_STATUS_CODES.include?(response.status) }

      attr_reader :max_retries, :delay, :should_retry, :retries_time_limit

      # @param max_retries [Integer] maximum number of retry attempts (0..10)
      # @param delay [Integer] base delay in seconds for exponential backoff (0..180)
      # @param should_retry [Proc] called with (delay, retry_count, response) before each attempt;
      #   returns whether the response should be retried. Defaults to {DEFAULT_SHOULD_RETRY}.
      # @param retries_time_limit [Numeric] maximum cumulative delay in seconds to spend waiting
      #   across all retries, or 0 (the default) for no limit
      def initialize(max_retries: 3, delay: 3, should_retry: DEFAULT_SHOULD_RETRY, retries_time_limit: 0)
        raise ArgumentError, "max_retries must be between 0 and #{MAX_RETRIES}" unless (0..MAX_RETRIES).cover?(max_retries)
        raise ArgumentError, "delay must be between 0 and #{MAX_DELAY}" unless (0..MAX_DELAY).cover?(delay)
        raise ArgumentError, 'retries_time_limit must be non-negative' if retries_time_limit.negative?

        @max_retries = max_retries
        @delay = delay
        @should_retry = should_retry
        @retries_time_limit = retries_time_limit
      end

      # @return [String] the key this option is registered under in the request context
      def get_key
        'retryHandler'
      end
    end
  end
end
