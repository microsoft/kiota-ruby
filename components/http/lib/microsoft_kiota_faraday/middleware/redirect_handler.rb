# frozen_string_literal: true

require 'faraday'
require 'uri'
require_relative 'redirect_handler_option'

module MicrosoftKiotaFaraday
  module Middleware
    class RedirectHandler < Faraday::Middleware
      REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
      ORIGIN_HEADERS = %w[Authorization Cookie Proxy-Authorization Host].freeze
      BODY_HEADERS = %w[Content-Length Transfer-Encoding Content-Type Content-Encoding].freeze

      def call(env)
        option = env.request.context&.[](RedirectHandlerOption::KEY)
        remaining = option&.max_redirects || RedirectHandlerOption::DEFAULT_MAX_REDIRECTS
        return @app.call(env) if remaining.zero? || env.parallel? || env.request.on_data

        request = Faraday::Env.from(env)
        buffer_body(request)
        loop do
          # The adapter adds response state to the environment it receives.
          response = @app.call(Faraday::Env.from(request))
          return response unless response.finished? && remaining.positive? && REDIRECT_STATUSES.include?(response.status)

          target = redirect_target(request.url, response.headers['Location'])
          return response unless target

          if origin(request.url) != origin(target)
            return response if client_certificate?(request.ssl)

            ORIGIN_HEADERS.each { |header| request.request_headers.delete(header) }
          end

          update_request(request, target, response.status)
          remaining -= 1
        end
      end

      private

      def buffer_body(request)
        return unless request.request_body.respond_to?(:read)

        body = request.request_body.read || +''
        request.request_body = body
        request.request_headers.delete('Transfer-Encoding')
        request.request_headers['Content-Length'] = body.bytesize.to_s
      end

      def redirect_target(url, location)
        return if location.nil? || location.strip.empty?

        target = URI.join(url.to_s, location.strip)
        return unless target.is_a?(URI::HTTP) && target.host && !target.host.empty? && !target.userinfo
        return if url.scheme == 'https' && target.scheme != 'https'

        target.fragment = nil
        target
      rescue URI::Error
        nil
      end

      def update_request(request, target, status)
        if switch_to_get?(request.method, status)
          request.method = :get
          request.request_body = nil
          BODY_HEADERS.each { |header| request.request_headers.delete(header) }
        end

        request.url = target
      end

      def switch_to_get?(method, status)
        return !%i[get head].include?(method) if status == 303

        [301, 302].include?(status) && method == :post
      end

      def origin(url)
        [url.scheme, url.host.downcase, url.port]
      end

      def client_certificate?(ssl)
        ssl && (ssl.client_cert || ssl.certificate)
      end
    end
  end
end
