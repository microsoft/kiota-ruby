# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module MicrosoftKiotaFaraday
  module Middleware
    # Request option controlling {RetryHandler}'s retry budget and backoff delay.
    class RetryHandlerOption
      include MicrosoftKiotaAbstractions::RequestOption

      MAX_RETRIES = 10
      MAX_DELAY = 180

      attr_reader :max_retries, :delay

      # @param max_retries [Integer] maximum number of retry attempts (0..10)
      # @param delay [Integer] base delay in seconds for exponential backoff (0..180)
      def initialize(max_retries: 3, delay: 3)
        raise ArgumentError, "max_retries must be between 0 and #{MAX_RETRIES}" unless (0..MAX_RETRIES).cover?(max_retries)
        raise ArgumentError, "delay must be between 0 and #{MAX_DELAY}" unless (0..MAX_DELAY).cover?(delay)

        @max_retries = max_retries
        @delay = delay
      end

      # @return [String] the key this option is registered under in the request context
      def get_key
        'retryHandler'
      end
    end
  end
end
