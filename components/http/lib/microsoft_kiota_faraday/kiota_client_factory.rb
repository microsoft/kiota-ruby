# frozen_string_literal: true

require 'net/https'
require 'faraday'
require_relative 'middleware/parameters_name_decoding_handler'
require_relative 'middleware/retry_handler'
require_relative 'middleware/user_agent_handler'
module MicrosoftKiotaFaraday
  class KiotaClientFactory
    def self.get_default_middleware
      [
        MicrosoftKiotaFaraday::Middleware::RetryHandler,
        MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler,
        MicrosoftKiotaFaraday::Middleware::UserAgentHandler
      ]
    end

    def self.get_default_http_client(middleware = nil, default_middleware_options = [])
      if middleware.nil? # empty is fine in case the user doesn't want to use any middleware
        middleware = get_default_middleware
      end
      connection_options = {}
      connection_options[:request] = {}
      connection_options[:request][:context] = {}
      unless default_middleware_options.nil? || default_middleware_options.empty?
        default_middleware_options.each do |value|
          connection_options[:request][:context][value.get_key] = value
        end
      end
      Faraday::Connection.new(nil, connection_options) do |builder|
        builder.adapter Faraday.default_adapter
        builder.ssl.verify = true
        builder.ssl.verify_mode = OpenSSL::SSL::VERIFY_PEER
        middleware.each do |handler|
          builder.use handler
        end
      end
    end
  end
end
