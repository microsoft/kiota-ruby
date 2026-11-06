# frozen_string_literal: true

module MicrosoftKiotaFaraday
  module Middleware
    # Raised by {RetryHandler} when its retry budget is exhausted without ever receiving
    # a non-retryable response.
    class RetryExhaustedError < StandardError
      # @return [Array<Faraday::Response>] every retryable response received, in attempt order
      attr_reader :responses

      # @param responses [Array<Faraday::Response>] every retryable response received, in attempt order
      def initialize(responses)
        @responses = responses
        super("Too many retries performed. More than #{responses.size - 1} retries encountered while sending the request.")
      end
    end
  end
end
