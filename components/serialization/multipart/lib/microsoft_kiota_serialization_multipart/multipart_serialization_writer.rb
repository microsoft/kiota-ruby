# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationMultipart
  class MultipartSerializationWriter
    include MicrosoftKiotaAbstractions::SerializationWriter

    def initialize
      @content = String.new(encoding: Encoding::BINARY)
    end

    def write_string_value(key, value)
      has_key = present?(key)
      has_value = present?(value)
      append(key) if has_key
      append(': ') if has_key && has_value
      append(value) if has_value
      append("\r\n")
    end

    def write_byte_array_value(_key, value)
      append(value) unless value.nil?
    end

    def write_object_value(_key, value, *_additional_values_to_merge)
      raise ArgumentError, "Expected a MultipartBody instance but got #{value.class}" unless value.is_a?(MicrosoftKiotaAbstractions::MultipartBody)

      serialize_body(value)
    end

    def get_serialized_content
      @content
    end

    private

    def present?(value)
      !value.nil? && !value.empty?
    end

    # every chunk is appended as bytes so UTF-8 text and raw binary parts can share the body
    def append(chunk)
      @content << chunk.b
    end

    def serialize_body(value)
      on_before_object_serialization&.call(value)
      on_start_object_serialization&.call(value, self)
      value.serialize(self)
    ensure
      on_after_object_serialization&.call(value)
    end
  end
end
