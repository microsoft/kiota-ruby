# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationJson
  class JsonSerializationWriterFactory
    include MicrosoftKiotaAbstractions::SerializationWriterFactory

    def get_valid_content_type
      'application/json'
    end

    def get_serialization_writer(content_type)
      raise ArgumentError, 'content type cannot be undefined or empty' if content_type.nil? || content_type.empty?
      raise ArgumentError, "expected a #{get_valid_content_type} content type" unless get_valid_content_type.casecmp?(content_type)

      JsonSerializationWriter.new
    end
  end
end
