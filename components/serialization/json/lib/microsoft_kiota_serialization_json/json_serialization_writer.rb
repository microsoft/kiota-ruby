# frozen_string_literal: true

require 'time'
require 'date'
require 'json'
require 'uuidtools'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationJson
  class JsonSerializationWriter
    include MicrosoftKiotaAbstractions::SerializationWriter

    def initialize
      @writer = {}
      @root_value = nil
      @has_root_value = false
    end

    attr_reader :writer, :root_value

    # A composed type whose selected member is a primitive serializes the scalar as the whole
    # document rather than as a member of an object, so a nil key means "this is the root".
    def set_root_value(value)
      @root_value = value
      @has_root_value = true
      value
    end

    def root_value?
      @has_root_value
    end

    def write_string_value(key, value)
      raise StandardError, 'no key or value included in write_string_value(key, value)' if key.nil? && value.nil?
      return set_root_value(value) if key.nil?
      return if value.nil?

      @writer[key] = value
    end

    def write_boolean_value(key, value)
      raise StandardError, 'no key or value included in write_boolean_value(key, value)' if key.nil? && value.nil?
      return set_root_value(value) if key.nil?
      return if value.nil?

      @writer[key] = value
    end

    def write_number_value(key, value)
      raise StandardError, 'no key or value included in write_number_value(key, value)' if key.nil? && value.nil?
      return set_root_value(value) if key.nil?
      return if value.nil?

      @writer[key] = value
    end

    def write_float_value(key, value)
      raise StandardError, 'no key or value included in write_float_value(key, value)' if key.nil? && value.nil?
      return set_root_value(value) if key.nil?
      return if value.nil?

      @writer[key] = value
    end

    def write_guid_value(key, value)
      raise StandardError, 'no key or value included in write_guid_value(key, value)' if !key && !value
      return set_root_value(value.to_s) unless key
      return if value.nil?

      @writer[key] = value.to_s
    end

    def write_date_value(key, value)
      raise StandardError, 'no key or value included in write_date_value(key, value)' if !key && !value
      return set_root_value(value.strftime('%Y-%m-%d')) unless key
      return if value.nil?

      @writer[key] = value.strftime('%Y-%m-%d')
    end

    def write_time_value(key, value)
      raise StandardError, 'no key or value included in write_time_value(key, value)' if !key && !value
      return set_root_value(value.strftime('%H:%M:%S%Z')) unless key
      return if value.nil?

      @writer[key] = value.strftime('%H:%M:%S%Z')
    end

    def write_date_time_value(key, value)
      raise StandardError, 'no key or value included in write_date_time_value(key, value)' if !key && !value
      return set_root_value(value.strftime('%Y-%m-%dT%H:%M:%S%Z')) unless key
      return if value.nil?

      @writer[key] = value.strftime('%Y-%m-%dT%H:%M:%S%Z')
    end

    def write_duration_value(key, value)
      raise StandardError, 'no key or value included in write_duration_value(key, value)' if !key && !value
      return set_root_value(value.string) unless key
      return if value.nil?

      @writer[key] = value.string
    end

    def write_byte_array_value(key, value)
      raise StandardError, 'no key or value included in write_byte_array_value(key, value)' if key.nil? && value.nil?
      return set_root_value([value].pack('m0')) if key.nil?
      return if value.nil?

      @writer[key] = [value].pack('m0')
    end

    def write_collection_of_primitive_values(key, values)
      return unless values

      serialized = values.map { |v| serialized_scalar(v) }
      return set_root_value(serialized) unless key

      @writer[key] = serialized
    end

    def write_collection_of_object_values(key, values)
      return unless values
      return set_root_value(values.map { |v| object_value_hash(v) }) unless key

      @writer[key] = values.map { |v| object_value_hash(v) }
    end

    def write_object_value(key, value, *additional_values_to_merge)
      values = [value, *additional_values_to_merge].compact
      return if values.empty?

      if key
        @writer[key] = object_value_hash(*values)
      else
        values.each { |v| serialize_object(v, self) }
      end
    end

    def write_null_value(key)
      return set_root_value(nil) if key.nil?

      @writer[key] = nil
    end

    def write_collection_of_enum_values(key, values)
      return unless values

      serialized = values.compact.map(&:to_s)
      return set_root_value(serialized) unless key

      @writer[key] = serialized
    end

    def write_enum_value(key, values)
      raise StandardError, 'no key or value included in write_enum_value(key, values)' if key.nil? && values.nil?
      return if values.nil?

      write_string_value(key, values.to_s)
    end

    def get_serialized_content
      (@has_root_value ? @root_value : @writer).to_json # TODO: encode to byte array to stay content type agnostic
    end

    def write_additional_data(value)
      return unless value

      value.each do |x, y|
        write_any_value(x, y)
      end
    end

    private

    def object_value_hash(value, *additional_values_to_merge)
      temp = child_writer
      serialize_object(value, temp)
      additional_values_to_merge.each { |v| serialize_object(v, temp) unless v.nil? }
      temp.writer
    end

    # the after hook runs even when writing the model raised, so callbacks can restore their state
    def serialize_object(value, writer)
      on_before_object_serialization&.call(value)
      on_start_object_serialization&.call(value, writer)
      value.serialize(writer)
    ensure
      on_after_object_serialization&.call(value)
    end

    # nested writers keep the callbacks so nested models write only their changes too
    def child_writer
      JsonSerializationWriter.new.tap do |writer|
        writer.on_before_object_serialization = on_before_object_serialization
        writer.on_after_object_serialization = on_after_object_serialization
        writer.on_start_object_serialization = on_start_object_serialization
      end
    end

    def write_hash_value(key, value)
      serialized = value.transform_values { |v| serialized_scalar(v) }
      return set_root_value(serialized) unless key

      @writer[key] = serialized
    end

    # a composed type wrapper writes its scalar as the root value, which a nested object hash would drop
    def write_parsable_value(key, value)
      return write_object_value(nil, value) unless key

      @writer[key] = serialized_scalar(value)
    end

    public

    def serialized_scalar(value)
      temp = child_writer
      temp.write_any_value(nil, value)
      temp.root_value? ? temp.root_value : temp.writer
    end

    def write_any_value(key, value)
      case value
      when nil then write_null_value(key)
      when true, false then write_boolean_value(key, value)
      when String, Symbol then write_string_value(key, value.to_s)
      when Integer then write_number_value(key, value)
      when Float then write_float_value(key, value)
      when DateTime then write_date_time_value(key, value)
      when Time then write_time_value(key, value)
      when Date then write_date_value(key, value)
      when MicrosoftKiotaAbstractions::ISODuration then write_duration_value(key, value)
      when UUIDTools::UUID then write_guid_value(key, value)
      when Array then write_collection_of_primitive_values(key, value)
      when Hash then write_hash_value(key, value)
      when MicrosoftKiotaAbstractions::Parsable then write_parsable_value(key, value)
      else raise StandardError, "Encountered an unknown type during serialization #{value.class} with key #{key}"
      end
    end
  end
end
