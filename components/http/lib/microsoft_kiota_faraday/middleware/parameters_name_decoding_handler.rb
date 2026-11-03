# frozen_string_literal: true

require 'faraday'
require_relative 'parameters_name_decoding_option'

module MicrosoftKiotaFaraday
  module Middleware
    class ParametersNameDecodingHandler < Faraday::Middleware
      @@default_option = ParametersNameDecodingOption.new

      def call(request_env)
        unless request_env[:request].nil? || request_env[:request][:context].nil?
          request_option = request_env[:request][:context][@@default_option.get_key]
        end
        request_option = @@default_option if request_option.nil?
        if request_env[:url] && request_option.enabled && request_option.characters_to_decode && !request_option.characters_to_decode.empty?
          uri = request_env[:url].is_a?(URI) ? request_env[:url] : URI.parse(request_env[:url].to_s)
          query = uri.query
          if query && !query.empty? && query.include?('%')
            decoded_query = decode_uri_encoded_string(query, request_option.characters_to_decode)
            if decoded_query != query
              uri = uri.dup
              uri.query = decoded_query
              request_env[:url] = uri
            end
          end
        end
        @app&.call(request_env)
      end

      def decode_uri_encoded_string(original, characters_to_decode)
        return original if original.nil? || original.empty? || characters_to_decode.nil? || characters_to_decode.empty?

        original.split('&').map do |part|
          next part if part.empty?

          if part.include?('=')
            name, value = part.split('=', 2)
            decoded_name = decode_parameter_name(name, characters_to_decode)
            "#{decoded_name}=#{value}"
          else
            decode_parameter_name(part, characters_to_decode)
          end
        end.join('&')
      end

      def decode_parameter_name(name, characters_to_decode)
        decoded = name.dup
        characters_to_decode.each do |character|
          decoded.gsub!(get_regex_for_character(character), character)
        end
        decoded
      end

      def get_regex_for_character(character)
        @regex_cache ||= {}
        @regex_cache[character] = Regexp.new("%#{character.ord.to_s(16)}", true) if @regex_cache[character].nil?
        @regex_cache[character]
      end
    end
  end
end
