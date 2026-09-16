# frozen_string_literal: true

require 'faraday'
require 'time'
require_relative 'retry_handler_option'

module MicrosoftKiotaFaraday
  module Middleware
    # Faraday middleware that retries 429, 503 and 504 responses with bounded
    # exponential backoff, honoring both delay-seconds and HTTP-date `Retry-After`
    # values. Behavior is tuned per request via a {RetryHandlerOption} placed in the
    # request context; see {RetryHandlerOption} for the available settings.
    class RetryHandler < Faraday::Middleware
      RETRY_STATUS_CODES = [429, 503, 504].freeze
      RETRY_ATTEMPT_HEADER = 'Retry-Attempt'
      RETRY_AFTER_HEADER = 'Retry-After'
      MAX_DELAY = RetryHandlerOption::MAX_DELAY
      DEFAULT_OPTION = RetryHandlerOption.new

      # @param request_env [Faraday::Env] the Faraday request environment
      # @return [Faraday::Response] the eventual response, once retries are exhausted
      #   or a non-retryable response is received
      def call(request_env)
        request_option = option_for(request_env)
        retries = 0
        request_body = request_env[:body]

        loop do
          request_env[:body] = request_body
          response = @app.call(request_env)
          return response unless retry?(response, request_body, retries, request_option)

          retries += 1
          request_env[:request_headers] ||= {}
          request_env[:request_headers][RETRY_ATTEMPT_HEADER] = retries.to_s
          request_body.rewind if request_body.respond_to?(:rewind)
          sleep retry_delay(response.headers[RETRY_AFTER_HEADER], retries, request_option)
        end
      end

      private

      def option_for(request_env)
        request_env.dig(:request, :context, DEFAULT_OPTION.get_key) || DEFAULT_OPTION
      end

      def retry?(response, request_body, retries, request_option)
        retries < request_option.max_retries &&
          RETRY_STATUS_CODES.include?(response.status) &&
          (!request_body.respond_to?(:read) || request_body.respond_to?(:rewind))
      end

      def retry_delay(value, retries, request_option)
        [retry_after(value) || (request_option.delay * (2**(retries - 1))), MAX_DELAY].min
      end

      def retry_after(value, now = Time.now.utc)
        return if value.nil?

        seconds = value.split(',').filter_map { |part| Float(part.strip, exception: false) }.find { |seconds| seconds >= 0 }
        return seconds if seconds

        begin
          delay = Time.httpdate(value) - now
        rescue ArgumentError
          # Retry-After wasn't a valid HTTP-date either; fall back to exponential backoff
          # instead of failing the request over a malformed header.
          return nil
        end
        delay if delay.positive?
      end
    end
  end
end
