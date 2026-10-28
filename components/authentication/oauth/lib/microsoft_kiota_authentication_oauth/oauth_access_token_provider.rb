# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require 'oauth2'
require_relative 'extensions/oauth2_ext'
require_relative 'contexts/client_credential_context'
require_relative 'contexts/authorization_code_context'
require_relative 'contexts/on_behalf_of_context'
require_relative 'contexts/oauth_context'
require_relative 'contexts/oauth_custom_flow'

module MicrosoftKiotaAuthenticationOAuth
  # Access Token Provider class implementation
  class OAuthAccessTokenProvider
    LOCALHOST_STRINGS = MicrosoftKiotaAbstractions::AllowedHostsValidator::LOCALHOST_STRINGS

    # This is the initializer for OAuthAccessTokenProvider.
    # :params
    #   token_request_context: a instance of one of our token request context or a custom implementation
    #   allowed_hosts: an array of strings, where each string is an allowed host, default is empty
    #   scopes: an array of strings, where each string is a scope, default is empty array
    def initialize(token_request_context, allowed_hosts = [], scopes = [])
      raise StandardError, 'Parameter token_request_context cannot be nil.' if token_request_context.nil?

      @token_request_context = token_request_context

      unless @token_request_context.is_a?(MicrosoftKiotaAuthenticationOAuth::OAuthContext)
        raise StandardError,
              'Parameter token_request_context must be an instance of one of our grant flow context classes.'
      end

      @cached_tokens = {}

      @host_validator = if allowed_hosts.nil? || allowed_hosts.empty?
                          MicrosoftKiotaAbstractions::AllowedHostsValidator.new([])
                        else
                          MicrosoftKiotaAbstractions::AllowedHostsValidator.new(allowed_hosts)
                        end
      @token_request_context.initialize_oauth_provider
      @scopes = if scopes.nil?
                  []
                else
                  scopes.dup
                end
    end

    # This function obtains the authorization token.
    # :params
    #   uri: a string containing the uri
    #   additional_params: hash of symbols to string values, ie { response_mode: 'fragment', prompt: 'login' }
    #                      default is empty hash
    def get_authorization_token(uri, _additional_properties = {})
      return Fiber.new { nil } if !uri || uri.to_s.empty?

      parsed_url = parse_uri(uri)
      return Fiber.new { nil } if parsed_url.nil? || !valid_host?(parsed_url)

      validate_scheme!(parsed_url)

      effective_scopes = determine_scopes(parsed_url)
      cache_key = effective_scopes.freeze
      Fiber.new do
        @token_request_context.initialize_scopes(effective_scopes)
        fetch_token(cache_key)
      end
    end

    attr_reader :scopes, :host_validator

    protected

    attr_writer :host_validator, :token_credential, :scopes, :cached_tokens

    private

    def parse_uri(uri)
      parsed = URI(uri)
      return nil if parsed.nil? || parsed.host.nil? || parsed.host.empty?

      parsed
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    def valid_host?(parsed_url)
      https_version = parsed_url.dup
      https_version.scheme = 'https'
      @host_validator.url_host_valid?(https_version.to_s)
    end

    def validate_scheme!(parsed_url)
      scheme = parsed_url.scheme&.downcase
      return if scheme == 'https' || (scheme == 'http' && localhost?(parsed_url))

      raise StandardError, 'Only https is supported'
    end

    def determine_scopes(parsed_url)
      @scopes.empty? ? ["#{parsed_url.scheme}://#{parsed_url.host}/.default"] : @scopes.dup
    end

    def fetch_token(cache_key)
      token_value = nil
      cached_token = @cached_tokens[cache_key]
      token_value = resolve_cached_token(cached_token, cache_key) unless cached_token.nil?

      if token_value.nil?
        token = @token_request_context.get_token
        unless token.nil?
          @cached_tokens[cache_key] = token.to_hash
          token_value = token.token
        end
      end

      token_value
    end

    def resolve_cached_token(cached_token, cache_key)
      token = OAuth2::AccessToken.from_hash(@token_request_context.oauth_provider, cached_token)
      return nil unless token

      if token.expired?
        return nil if token.refresh_token.nil? || token.refresh_token.empty?

        token = token.refresh!
        @cached_tokens[cache_key] = token.to_hash
      end
      token.token
    end

    def localhost?(parsed_url)
      if @host_validator.respond_to?(:localhost?)
        @host_validator.localhost?(parsed_url)
      else
        host = parsed_url.host
        return false if host.nil?

        return true if LOCALHOST_STRINGS.include?(host.downcase)

        hostname = parsed_url.hostname
        return false if hostname.nil?

        LOCALHOST_STRINGS.include?(hostname.downcase)
      end
    end
  end
end
