# frozen_string_literal: true

require_relative 'authentication_provider'
require_relative 'access_token_provider'

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
      if request.headers.get_all.key?(AUTHORIZATION_HEADER_KEY)
        Fiber.new do
        end
      else
        Fiber.new do
          auth_fiber = @access_token_provider.get_authorization_token(request.uri, additional_properties)
          token = auth_fiber.resume if auth_fiber
          request.headers.add(AUTHORIZATION_HEADER_KEY, "Bearer #{token}") unless token.nil? || token.empty?
        end
      end
    end
  end
end
