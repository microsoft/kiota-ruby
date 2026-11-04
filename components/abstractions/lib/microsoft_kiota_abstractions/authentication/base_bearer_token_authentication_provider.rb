# frozen_string_literal: true

require_relative 'authentication_provider'
require_relative 'access_token_provider'
require_relative '../request_headers'

module MicrosoftKiotaAbstractions
  # Provides a base class for implementing AuthenticationProvider for Bearer token scheme
  class BaseBearerTokenAuthenticationProvider
    include MicrosoftKiotaAbstractions::AuthenticationProvider

    def initialize(access_token_provider)
      raise StandardError, 'access_token_provider parameter cannot be nil' if access_token_provider.nil?

      @access_token_provider = access_token_provider
    end

    AUTHORIZATION_HEADER_KEY = 'Authorization'
    def authenticate_request(request, additional_properties = {})
      raise StandardError, 'Request cannot be null' if request.nil?

      # If request contains already an authorization header, nothing needs to be done.
      has_auth_header = if request.headers.respond_to?(:key?)
                          request.headers.key?(AUTHORIZATION_HEADER_KEY)
                        elsif request.headers.respond_to?(:get_all) && request.headers.get_all
                          request.headers.get_all.keys.any? { |k| k.to_s.casecmp?(AUTHORIZATION_HEADER_KEY) }
                        else
                          false
                        end

      if has_auth_header
        Fiber.new do
        end
      else
        Fiber.new do
          auth_fiber = @access_token_provider.get_authorization_token(request.uri, additional_properties)
          token = auth_fiber.resume if auth_fiber
          unless token.nil? || token.empty?
            headers = ensure_request_headers(request)
            headers.add(AUTHORIZATION_HEADER_KEY, "Bearer #{token}")
          end
        end
      end
    end

    private

    def ensure_request_headers(request)
      return request.headers unless request.headers.nil?

      headers = RequestHeaders.new
      if request.respond_to?(:headers=)
        request.headers = headers
      elsif request.instance_variable_defined?(:@headers)
        request.instance_variable_set(:@headers, headers)
      end
      headers
    end
  end
end
