# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require 'faraday'
require 'net/http'
require 'stringio'
require_relative 'kiota_client_factory'
require_relative 'request_body'
require_relative 'middleware/response_handler_option'

module MicrosoftKiotaFaraday
  class FaradayRequestAdapter
    include MicrosoftKiotaAbstractions::RequestAdapter

    attr_accessor :authentication_provider, :content_type_header_key, :parse_node_factory,
                  :serialization_writer_factory, :client

    def initialize(authentication_provider,
                   parse_node_factory = MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance, serialization_writer_factory = MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.default_instance, client = KiotaClientFactory.get_default_http_client)
      raise StandardError, 'authentication provider cannot be null' unless authentication_provider

      @authentication_provider = authentication_provider
      @content_type_header_key = 'Content-Type'
      @parse_node_factory = parse_node_factory
      if @parse_node_factory.nil?
        @parse_node_factory = MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance
      end
      @serialization_writer_factory = serialization_writer_factory
      if @serialization_writer_factory.nil?
        @serialization_writer_factory = MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.default_instance
      end
      @client = client
      @client = KiotaClientFactory.get_default_http_client if @client.nil?
      @base_url = ''
    end

    def set_base_url(base_url)
      @base_url = base_url
    end

    def get_base_url
      @base_url
    end

    def get_serialization_writer_factory
      @serialization_writer_factory
    end

    PRIMITIVE_READERS = {
      'String' => :get_string_value,
      'Float' => :get_float_value,
      'Integer' => :get_number_value,
      'Date' => :get_date_value,
      'DateTime' => :get_date_time_value,
      'Time' => :get_time_value,
      'MicrosoftKiotaAbstractions::ISODuration' => :get_duration_value,
      'UUIDTools::UUID' => :get_guid_value,
      'boolean' => :get_boolean_value,
      'Boolean' => :get_boolean_value
    }.freeze

    def send_async(request_info, factory, errors_mapping)
      raise StandardError, 'factory cannot be null' unless factory

      execute_async(request_info, errors_mapping) do |response|
        get_root_parse_node(response)&.get_object_value(factory)
      end
    end

    def send_collection_async(request_info, factory, errors_mapping)
      raise StandardError, 'factory cannot be null' unless factory

      execute_async(request_info, errors_mapping) do |response|
        get_root_parse_node(response)&.get_collection_of_object_values(factory)
      end
    end

    def send_collection_of_primitive_async(request_info, type, errors_mapping)
      execute_async(request_info, errors_mapping) do |response|
        root_node = get_root_parse_node(response)
        next root_node&.get_collection_of_enum_values(type) if type.is_a?(Hash)

        root_node&.get_collection_of_primitive_values(type)
      end
    end

    def send_primitive_async(request_info, type, errors_mapping)
      execute_async(request_info, errors_mapping) do |response|
        next StringIO.new(response.body.to_s) if type == StringIO
        next get_root_parse_node(response)&.get_enum_value(type) if type.is_a?(Hash)

        reader = PRIMITIVE_READERS[type.to_s]
        raise StandardError, "unexpected primitive response type #{type}" if reader.nil?

        get_root_parse_node(response)&.public_send(reader)
      end
    end

    def send_no_response_content_async(request_info, errors_mapping)
      execute_async(request_info, errors_mapping) { nil }
    end

    def execute_async(request_info, errors_mapping)
      raise StandardError, 'request_info cannot be null' unless request_info

      Fiber.new do
        set_base_url_for_request_information(request_info)
        @authentication_provider.authenticate_request(request_info).resume
        request = get_request_from_request_info(request_info)
        response = @client.run_request(request.http_method, request.path, request.body, request.headers)

        response_handler = get_response_handler(request_info)
        response_handler&.call(response)&.resume
        throw_if_failed_reponse(response, errors_mapping)
        yield response
      end
    end

    def get_response_handler(request_info)
      unless request_info.nil?
        option = request_info.get_request_option(MicrosoftKiotaFaraday::Middleware::ResponseHandlerOption::RESPONSE_HANDLER_KEY)
      end
      option.async_callback unless !option || option.nil?
    end

    def get_root_parse_node(response)
      raise StandardError, 'response cannot be null' unless response

      return if response.body.nil? || response.body.empty?

      response_content_type = get_response_content_type(response)
      raise StandardError, 'no response content type found for deserialization' unless response_content_type

      @parse_node_factory.get_parse_node(response_content_type, response.body)
    end

    def throw_if_failed_reponse(response, errors_mapping)
      raise StandardError, 'response cannot be null' unless response

      status_code = response.status
      return if status_code < 400

      error_factory = errors_mapping[status_code.to_s] unless errors_mapping.nil?
      error_factory = errors_mapping['4XX'] unless !error_factory.nil? || errors_mapping.nil? || status_code > 500
      unless !error_factory.nil? || errors_mapping.nil? || status_code < 500 || status_code > 600
        error_factory = errors_mapping['5XX']
      end
      unless !error_factory.nil? || errors_mapping.nil? || status_code < 400 || status_code > 600
        error_factory = errors_mapping['XXX']
      end
      if error_factory.nil?
        raise MicrosoftKiotaAbstractions::ApiError,
              "The server returned an unexpected status code and no error factory is registered for this code:#{status_code}"
      end

      root_node = get_root_parse_node(response)
      error = root_node.get_object_value(error_factory) unless root_node.nil?
      raise error unless error.nil?

      raise MicrosoftKiotaAbstractions::ApiError, "The server returned an unexpected status code:#{status_code}"
    end

    def get_request_from_request_info(request_info)
      set_base_url_for_request_information(request_info)
      case request_info.http_method
      when :GET, :POST, :PATCH, :DELETE, :OPTIONS, :CONNECT, :PUT, :TRACE, :HEAD, :QUERY
        request = @client.build_request(request_info.http_method.downcase)
      else
        raise StandardError, 'unsupported http method'
      end
      request.path = request_info.uri
      unless request_info.headers.nil?
        request.headers = Faraday::Utils::Headers.new
        request_info.headers.get_all.select do |k, v|
          request.headers[k] = if v.is_a? Array
                                 v.join(',')
                               elsif v.is_a? String
                                 v
                               else
                                 v.to_s
                               end
        end
      end
      RequestBody.apply(request, request_info.content)
      request_options = request_info.get_request_options
      if !request_options.nil? && !request_options.empty?
        request.options = Faraday::RequestOptions.new if request.options.nil?
        request_options.each do |value|
          request.options.context[value.get_key] = value
        end
      end
      request
    end

    def get_response_content_type(response)
      response.headers['content-type'].split(';')[0].downcase
    rescue StandardError
      nil
    end

    def convert_to_native_request_async(request_info)
      raise StandardError, 'request_info cannot be null' unless request_info

      Fiber.new do
        set_base_url_for_request_information(request_info)
        @authentication_provider.authenticate_request(request_info).resume
        return get_request_from_request_info(request_info)
      end
    end

    private

    def set_base_url_for_request_information(request_info)
      request_info.path_parameters['baseurl'] = @base_url
    end
  end
end
