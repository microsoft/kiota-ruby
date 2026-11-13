# frozen_string_literal: true

module MicrosoftKiotaFaraday
  module Middleware
    # Raised by {RetryHandler} when its retry budget is exhausted without ever receiving
    # a non-retryable response.
    class RetryExhaustedError < StandardError
      # @param retries [Integer] the number of retries performed
      def initialize(retries)
        super("Too many retries performed. #{retries} retries encountered while sending the request.")
      end
    end
  end
end
