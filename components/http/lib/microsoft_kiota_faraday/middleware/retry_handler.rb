# frozen_string_literal: true

require 'faraday'
require 'time'

module MicrosoftKiotaFaraday
  module Middleware
    class RetryHandler < Faraday::Middleware
      RETRY_STATUS_CODES = [429, 503, 504].freeze
      RETRY_ATTEMPT_HEADER = 'Retry-Attempt'
      RETRY_AFTER_HEADER = 'Retry-After'
      DEFAULT_MAX_RETRIES = 3
      MAX_RETRIES = 10
      DEFAULT_DELAY = 3
      MAX_DELAY = 180

      def initialize(app, options = {})
        super(app)
        @max_retries = options.fetch(:max_retries, DEFAULT_MAX_RETRIES)
        @delay = options.fetch(:delay, DEFAULT_DELAY)

        raise ArgumentError, "max_retries must be between 0 and #{MAX_RETRIES}" unless (0..MAX_RETRIES).cover?(@max_retries)
        raise ArgumentError, "delay must be between 0 and #{MAX_DELAY}" unless (0..MAX_DELAY).cover?(@delay)
      end

      def call(request_env)
        retries = 0
        request_body = request_env[:body]

        loop do
          request_env[:body] = request_body
          response = @app.call(request_env)
          return response unless retry?(response, request_body, retries)

          retries += 1
          request_env[:request_headers] ||= {}
          request_env[:request_headers][RETRY_ATTEMPT_HEADER] = retries.to_s
          request_body.rewind if request_body.respond_to?(:rewind)
          sleep retry_delay(response.headers[RETRY_AFTER_HEADER], retries)
        end
      end

      private

      def retry?(response, request_body, retries)
        retries < @max_retries &&
          RETRY_STATUS_CODES.include?(response.status) &&
          (!request_body.respond_to?(:read) || request_body.respond_to?(:rewind))
      end

      def retry_delay(value, retries)
        [retry_after(value) || (@delay * (2**(retries - 1))), MAX_DELAY].min
      end

      def retry_after(value, now = Time.now.utc)
        return if value.nil?

        seconds = value.split(',').filter_map { |part| Float(part.strip, exception: false) }.find(&:positive?)
        return seconds if seconds

        delay = Time.httpdate(value) - now
        delay if delay.positive?
      rescue ArgumentError
        nil
      end
    end
  end
end
