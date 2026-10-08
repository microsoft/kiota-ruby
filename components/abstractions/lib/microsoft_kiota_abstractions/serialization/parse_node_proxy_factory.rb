# frozen_string_literal: true

require_relative 'parse_node_factory'

module MicrosoftKiotaAbstractions
  # Wraps a parse node factory to run callbacks before and after every model is filled
  class ParseNodeProxyFactory
    include ParseNodeFactory

    def initialize(concrete, on_before, on_after)
      raise ArgumentError, 'concrete factory cannot be nil' if concrete.nil?

      @concrete = concrete
      @on_before = on_before
      @on_after = on_after
    end

    def get_valid_content_type
      @concrete.get_valid_content_type
    end

    def get_parse_node(content_type, content)
      node = @concrete.get_parse_node(content_type, content)
      original_before = node.on_before_assign_field_values
      original_after = node.on_after_assign_field_values
      node.on_before_assign_field_values = lambda do |value|
        @on_before&.call(value)
        original_before&.call(value)
      end
      # after callbacks unwind the before ones, and run even when an inner one raised
      node.on_after_assign_field_values = lambda do |value|
        original_after&.call(value)
      ensure
        @on_after&.call(value)
      end
      node
    end
  end
end
