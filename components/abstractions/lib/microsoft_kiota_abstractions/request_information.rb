# frozen_string_literal: true

require 'date'
require 'time'
require 'uri'
require 'stduritemplate'
require_relative 'http_method'
require_relative 'multipart_body'
require_relative 'request_headers'

module MicrosoftKiotaAbstractions
  class RequestInformation
    attr_reader :content, :http_method, :headers
    attr_accessor :url_template, :path_parameters, :query_parameters

    @@binary_content_type = 'application/octet-stream'
    @@content_type_header = 'Content-Type'
    @@raw_url_key = 'request-raw-url'

    def initialize
      @headers = RequestHeaders.new
      @query_parameters = {}
      @path_parameters = {}
    end

    def uri=(arg)
      raise ArgumentError, 'arg cannot be nil or empty' if arg.nil? || arg.empty?

      path_parameters.clear
      query_parameters.clear
      @uri = URI(arg)
    end

    def uri
      return @uri unless @uri.nil?

      if path_parameters[@@raw_url_key].nil?
        values = path_parameters.merge(query_parameters).transform_values { |v| template_value(v) }
        return URI(StdUriTemplate.expand(@url_template, values))
      end

      self.uri = path_parameters[@@raw_url_key]
      @uri
    end

    def add_request_options(request_options_to_add)
      return if request_options_to_add.nil?

      @request_options ||= {}
      request_options_to_add = [request_options_to_add] unless request_options_to_add.is_a?(Array)
      request_options_to_add.each do |request_option|
        key = request_option.get_key
        @request_options[key] = request_option
      end
    end

    def get_request_options
      return [] if @request_options.nil?

      @request_options.values
    end

    def get_request_option(key)
      return nil if @request_options.nil? || key.nil? || key.empty?

      @request_options[key]
    end

    def remove_request_options(keys)
      return if keys.nil? || @request_options.nil?

      keys = [keys] unless keys.is_a?(Array)
      keys.each do |key|
        @request_options.delete(key)
      end
    end

    def http_method=(method)
      @http_method = HttpMethod::HTTP_METHOD[method]
    end

    def set_stream_content(value = $stdin, content_type)
      @content = value
      content_type = @@binary_content_type if content_type.nil? || content_type.empty?
      @headers.try_add(@@content_type_header, content_type)
    end

    SCALAR_WRITERS = {
      'String' => :write_string_value,
      'Integer' => :write_number_value,
      'Float' => :write_float_value,
      'TrueClass' => :write_boolean_value,
      'FalseClass' => :write_boolean_value,
      'Date' => :write_date_value,
      'DateTime' => :write_date_time_value,
      'Time' => :write_time_value,
      'MicrosoftKiotaAbstractions::ISODuration' => :write_duration_value,
      'UUIDTools::UUID' => :write_guid_value,
      'Symbol' => :write_enum_value
    }.freeze

    def set_content_from_scalar(request_adapter, content_type, values)
      writer = request_adapter.get_serialization_writer_factory.get_serialization_writer(content_type)
      @headers.try_add(@@content_type_header, content_type)
      if values.is_a?(Array)
        writer.write_collection_of_primitive_values(nil, values)
      else
        method = SCALAR_WRITERS[values.class.to_s]
        raise StandardError, "unknown type during serialization: #{values.class}" if method.nil?

        writer.public_send(method, nil, values)
      end
      @content = writer.get_serialized_content
    end

    def set_content_from_parsable(request_adapter, content_type, values)
      writer = request_adapter.get_serialization_writer_factory.get_serialization_writer(content_type)
      if values.is_a?(MultipartBody)
        content_type = "#{content_type.gsub(/;\s*boundary=[^;]*/i, '')}; boundary=#{values.boundary}"
        values.request_adapter = request_adapter
        @headers.remove(@@content_type_header)
      end
      @headers.try_add(@@content_type_header, content_type)
      if !values.nil? && values.is_a?(Array)
        writer.write_collection_of_object_values(nil, values)
      else
        writer.write_object_value(nil, values)
      end
      @content = writer.get_serialized_content
    end

    def add_headers_from_raw_object(h)
      h&.get_all&.select { |x, y| @headers.add(x.to_s, y) }
    end

    def set_query_string_parameters_from_raw_object(q)
      return if !q || q.is_a?(Hash) || q.is_a?(Array)

      q.class.instance_methods(false).select do |x|
        method_name = x.to_s
        if method_name == 'compare_by_identity' || method_name == 'get_query_parameter' || method_name.end_with?('=') || method_name.end_with?('?') || method_name.end_with?('!')
          next
        end

        begin
          key = q.get_query_parameter(method_name)
        rescue StandardError
          key = method_name
        end
        value = eval("q.#{method_name}")
        query_parameters[key] = value unless value.nil?
      end
    end

    private

    # the template engine only takes strings, numbers, booleans and lists of them
    def template_value(value)
      case value
      when nil, String, Integer, Float, true, false then value
      when Array then value.map { |v| template_value(v) }
      when Hash then value.transform_values { |v| template_value(v) }
      when Date, Time then value.iso8601
      when MicrosoftKiotaAbstractions::ISODuration then value.string
      else value.to_s
      end
    end
  end
end
