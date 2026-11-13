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

      attr_reader :max_retries, :delay, :should_retry, :retries_time_limit, :retry_unprocessed_mutations_only

      # @param max_retries [Integer] maximum number of retry attempts (0..10)
      # @param delay [Integer] base delay in seconds for exponential backoff (0..180)
      # @param should_retry [Proc] called with (delay, retry_count, response) before each attempt;
      #   returns whether the response should be retried. Defaults to {DEFAULT_SHOULD_RETRY}.
      # @param retries_time_limit [Numeric] maximum cumulative delay in seconds to spend waiting
      #   across all retries, or 0 (the default) for no limit
      # @param retry_unprocessed_mutations_only [Boolean] whether POST and PATCH requests are retried
      #   only after a response showing the server didn't process them. Defaults to false.
      #   POST and PATCH aren't idempotent, so resending one the server already processed can repeat
      #   its side effect, such as sending an email twice. A 504 can arrive after the server processed
      #   the request. When this is true, POST and PATCH requests are retried only after a 429 or 503
      #   response, and any other response is returned to the caller, even when should_retry accepts it.
      #   This relies on the common service convention, followed by Microsoft Graph, that a 429 or 503
      #   response means the server didn't process the request. HTTP doesn't guarantee this, so a
      #   service that returns 429 or 503 after acting on a request can still see it repeated. PUT and
      #   DELETE also change state, but they're idempotent, so they aren't affected, and neither are
      #   other methods.
      def initialize(max_retries: 3, delay: 3, should_retry: DEFAULT_SHOULD_RETRY, retries_time_limit: 0,
                     retry_unprocessed_mutations_only: false)
        raise ArgumentError, "max_retries must be between 0 and #{MAX_RETRIES}" unless max_retries.is_a?(Integer) && (0..MAX_RETRIES).cover?(max_retries)
        raise ArgumentError, "delay must be between 0 and #{MAX_DELAY}" unless (0..MAX_DELAY).cover?(delay)
        raise ArgumentError, 'retries_time_limit must be non-negative' if retries_time_limit.negative?

        @max_retries = max_retries
        @delay = delay
        @should_retry = should_retry
        @retries_time_limit = retries_time_limit
        @retry_unprocessed_mutations_only = retry_unprocessed_mutations_only
      end

      # @return [String] the key this option is registered under in the request context
      def get_key
        'retryHandler'
      end
    end
  end
end
