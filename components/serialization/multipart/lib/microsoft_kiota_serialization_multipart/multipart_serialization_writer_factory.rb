# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require_relative 'multipart_serialization_writer'

module MicrosoftKiotaSerializationMultipart
  class MultipartSerializationWriterFactory
    include MicrosoftKiotaAbstractions::SerializationWriterFactory

    def get_valid_content_type
      'multipart/form-data'
    end

    def get_serialization_writer(content_type)
      raise ArgumentError, 'content type cannot be undefined or empty' if content_type.nil? || content_type.empty?
      raise ArgumentError, "expected a #{get_valid_content_type} content type" unless get_valid_content_type.casecmp?(content_type)

      MultipartSerializationWriter.new
    end
  end
end
