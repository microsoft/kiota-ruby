# frozen_string_literal: true

require_relative 'parse_node_factory'

module MicrosoftKiotaAbstractions
  class ParseNodeFactoryRegistry
    include ParseNodeFactory

    class << self
      attr_accessor :default_instance

      def default_instance = @default_instance ||= ParseNodeFactoryRegistry.new
    end

    def default_instance
      self.class.default_instance
    end

    def content_type_associated_factories
      @content_type_associated_factories ||= {}
    end

    def get_parse_node(content_type, content)
      raise StandardError, 'content type cannot be undefined or empty' if content_type.nil? || content_type.strip.empty?
      raise StandardError, 'content cannot be undefined or empty' if content.nil? || (content.respond_to?(:empty?) && content.empty?)

      vendor_specific_content_type = content_type.split(';').first.strip
      factory = content_type_associated_factories[vendor_specific_content_type]
      return factory.get_parse_node(vendor_specific_content_type, content) if factory

      clean_content_type = get_clean_content_type(vendor_specific_content_type)
      factory = content_type_associated_factories[clean_content_type]
      return factory.get_parse_node(clean_content_type, content) if factory

      raise StandardError, "Content type #{content_type} does not have a factory to be parsed"
    end

    private

    def get_clean_content_type(content_type)
      plus_index = content_type.rindex('+')
      return content_type unless plus_index

      slash_index = content_type.rindex('/', plus_index)
      return content_type unless slash_index && slash_index < plus_index

      "#{content_type[0..slash_index]}#{content_type[(plus_index + 1)..]}"
    end
  end
end
