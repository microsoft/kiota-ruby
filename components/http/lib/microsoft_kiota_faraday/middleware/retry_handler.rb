# frozen_string_literal: true

require 'faraday'
require 'time'
require_relative 'retry_handler_option'
require_relative 'retry_exhausted_error'

module MicrosoftKiotaFaraday
  module Middleware
    # Faraday middleware that retries 429, 503 and 504 responses with bounded
    # exponential backoff, honoring both delay-seconds and HTTP-date `Retry-After`
    # values. Behavior is tuned via a {RetryHandlerOption} placed in the request context,
    # falling back to the handler's default option; see {RetryHandlerOption} for the
    # available settings.
    class RetryHandler < Faraday::Middleware
      RETRY_ATTEMPT_HEADER = 'Retry-Attempt'
      RETRY_AFTER_HEADER = 'Retry-After'
      MAX_DELAY = RetryHandlerOption::MAX_DELAY
      DRAIN_CHUNK_SIZE = 16 * 1024

      # @param app [#call] the next Faraday handler in the stack
      # @param default_option [RetryHandlerOption, nil] used for requests that don't carry their
      #   own {RetryHandlerOption} in the request context; defaults to `RetryHandlerOption.new`
      def initialize(app = nil, default_option = nil)
        super(app)
        @default_option = default_option || RetryHandlerOption.new
      end

      # @param request_env [Faraday::Env] the Faraday request environment
      # @return [Faraday::Response] the eventual response, once a non-retryable response is received
      # @raise [RetryExhaustedError] if the retry budget is exhausted while responses remain retryable
      def call(request_env)
        return @app.call(request_env) if request_env.is_a?(Faraday::Env) && (request_env.parallel? || request_env.request.on_data)

        request_option = option_for(request_env)
        request_body = request_env[:body]
        position = body_position(request_body)
        response = @app.call(retry_env(request_env, request_body, nil))

        return response unless request_option.max_retries.positive? && retryable?(response, request_body, 0, request_option)

        retry_until_resolved(request_env, request_body, response, request_option, position)
      end

      private

      def option_for(request_env)
        request_option = request_env[:request]&.[](:context)&.[](@default_option.get_key)
        request_option || @default_option
      end

      # Retries request_env until a non-retryable response is received, the configured
      # retries_time_limit would be exceeded, or the retry budget runs out.
      def retry_until_resolved(request_env, request_body, response, request_option, position)
        retries = 0
        cumulative_delay = 0

        loop do
          if retries >= request_option.max_retries
            drain(response)
            raise RetryExhaustedError, retries
          end
          delay = retry_delay(response.headers[RETRY_AFTER_HEADER], retries, request_option)

          if request_option.retries_time_limit.positive?
            cumulative_delay += delay
            return response if cumulative_delay > request_option.retries_time_limit
          end
          return response unless restore_body(request_body, position)

          drain(response)

          retries += 1
          sleep delay
          response = @app.call(retry_env(request_env, request_body, retries))
          return response unless retryable?(response, request_body, retries, request_option)
        end
      end

      # Builds a fresh env for a retry attempt instead of mutating request_env in place, so the
      # caller's original headers/body are left untouched even after several retries.
      def retry_env(request_env, request_body, retries)
        env = request_env.dup
        env[:request_headers] = (request_env[:request_headers] || {}).dup
        env[:request_headers][RETRY_ATTEMPT_HEADER] = retries.to_s if retries
        env[:body] = request_body
        env
      end

      def retryable?(response, request_body, retries, request_option)
        (!request_body.respond_to?(:read) || request_body.respond_to?(:seek)) &&
          request_option.should_retry.call(request_option.delay, retries, response)
      end

      def retry_delay(value, retries, request_option)
        [retry_after(value) || (request_option.delay * (2**retries)), MAX_DELAY].min
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
        [delay, 0].max
      end

      # Drain and close discarded response streams without retaining their contents.
      def drain(response)
        body = response.body
        return response unless body.respond_to?(:read)

        begin
          loop do
            chunk = body.read(DRAIN_CHUNK_SIZE)
            break if chunk.nil? || chunk.empty?
          end
        ensure
          body.close if body.respond_to?(:close)
        end
      end

      def body_position(body)
        return unless body.respond_to?(:read) && body.respond_to?(:pos) && body.respond_to?(:seek)

        body.pos
      rescue IOError, SystemCallError
        nil
      end

      def restore_body(body, position)
        return true unless body.respond_to?(:read)
        return false if position.nil?

        body.seek(position)
        true
      rescue IOError, SystemCallError
        # Pipes can expose seek while still being non-seekable on MRI and JRuby.
        false
      end
    end
  end
end
