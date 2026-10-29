# frozen_string_literal: true

require 'date'
require 'time'
require 'uri'
require 'uuidtools'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationForm
  class FormSerializationWriter
    include MicrosoftKiotaAbstractions::SerializationWriter

    NESTED_OBJECTS = 'Form serialization does not support nested objects.'

    def initialize
      @buffer = +''
      @depth = 0
    end

    def write_string_value(key, value)
      return if key.nil? || key.empty? || value.nil?

      @buffer << '&' unless @buffer.empty?
      @buffer << URI.encode_www_form_component(key) << '=' << URI.encode_www_form_component(value)
    end

    def write_boolean_value(key, value) = write_string_value(key, value&.to_s)

    def write_number_value(key, value) = write_string_value(key, value&.to_s)

    def write_float_value(key, value) = write_string_value(key, value&.to_s)

    def write_guid_value(key, value) = write_string_value(key, value&.to_s)

    def write_date_value(key, value)
      value = value.strftime('%Y-%m-%d') if value.respond_to?(:strftime)
      write_string_value(key, value)
    end

    def write_time_value(key, value)
      value = value.strftime(fraction?(value) ? '%H:%M:%S.%6N' : '%H:%M:%S') if value.respond_to?(:strftime)
      write_string_value(key, value)
    end

    def write_date_time_value(key, value)
      value = value.iso8601(fraction?(value) ? 6 : 0) if value.is_a?(Time) || value.is_a?(DateTime)
      write_string_value(key, value)
    end

    def write_duration_value(key, value)
      value = value.string if value.is_a?(MicrosoftKiotaAbstractions::ISODuration)
      write_string_value(key, value)
    end

    def write_byte_array_value(key, value)
      write_string_value(key, [value].pack('m0')) unless value.nil?
    end

    # a flags value is an Array of members
    def write_enum_value(key, value)
      members = Array(value).compact
      write_string_value(key, members.join(',')) unless members.empty?
    end

    def write_null_value(key) = write_string_value(key, 'null')

    def write_collection_of_primitive_values(key, values)
      values&.each { |value| write_any_value(key, value) }
    end

    def write_collection_of_enum_values(key, values)
      values&.each { |value| write_string_value(key, value&.to_s) }
    end

    def write_collection_of_object_values(_key, values)
      return if values.nil?

      raise StandardError, 'Form serialization does not support collections.'
    end

    # written flat, as .NET does; inside a model only a composed type member (nil key) is allowed
    def write_object_value(key, value, *additional_values_to_merge)
      values = [value, *additional_values_to_merge].compact
      return if values.empty?
      raise StandardError, NESTED_OBJECTS if @depth.positive? && !(key.nil? || key.empty?)

      writer = child_writer
      values.each { |v| serialize_object(v, writer) }
      content = writer.get_serialized_content
      return if content.empty?

      @buffer << '&' unless @buffer.empty?
      @buffer << content
    end

    def write_additional_data(value)
      value&.each { |key, data| write_any_value(key, data) }
    end

    def write_any_value(key, value)
      case value
      when nil then nil
      when String, Symbol then write_string_value(key, value.to_s)
      when true, false then write_boolean_value(key, value)
      when Integer then write_number_value(key, value)
      when Float then write_float_value(key, value)
      when UUIDTools::UUID then write_guid_value(key, value)
      when DateTime, Time then write_date_time_value(key, value)
      when Date then write_date_value(key, value)
      when MicrosoftKiotaAbstractions::ISODuration then write_duration_value(key, value)
      when Array then write_collection_of_primitive_values(key, value)
      when Hash, MicrosoftKiotaAbstractions::Parsable then raise StandardError, NESTED_OBJECTS
      else raise StandardError, "Encountered an unknown type during serialization #{value.class} with key #{key}"
      end
    end

    def get_serialized_content
      @buffer.dup
    end

    protected

    attr_writer :depth

    private

    def fraction?(value)
      fraction = if value.respond_to?(:subsec) then value.subsec
                 elsif value.respond_to?(:sec_fraction) then value.sec_fraction
                 else 0
                 end
      !fraction.zero?
    end

    # the after hook runs even when writing the model raised, so callbacks can restore their state
    def serialize_object(value, writer)
      on_before_object_serialization&.call(value)
      on_start_object_serialization&.call(value, writer)
      value.serialize(writer)
    ensure
      on_after_object_serialization&.call(value)
    end

    def child_writer
      FormSerializationWriter.new.tap do |writer|
        writer.depth = @depth + 1
        writer.on_before_object_serialization = on_before_object_serialization
        writer.on_after_object_serialization = on_after_object_serialization
        writer.on_start_object_serialization = on_start_object_serialization
      end
    end
  end
end
