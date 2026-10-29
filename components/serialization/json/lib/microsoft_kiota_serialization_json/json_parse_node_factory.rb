# frozen_string_literal: true

require 'json'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationJson
  class JsonParseNodeFactory
    include MicrosoftKiotaAbstractions::ParseNodeFactory

    def get_valid_content_type
      'application/json'
    end

    def get_parse_node(content_type, content)
      raise ArgumentError, 'content type cannot be undefined or empty' if content_type.nil? || content_type.empty?
      raise ArgumentError, "expected a #{get_valid_content_type} content type" unless get_valid_content_type.casecmp?(content_type)
      raise ArgumentError, 'content cannot be undefined or empty' if content.nil?

      JsonParseNode.new(JSON.parse(content))
    end
  end
end
