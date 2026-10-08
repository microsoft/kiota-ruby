# frozen_string_literal: true

require 'time'
require 'date'
require 'json'
require 'uuidtools'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationJson
  class JsonParseNode
    include MicrosoftKiotaAbstractions::ParseNode

    def initialize(node)
      @current_node = node
    end

    # The scalar readers answer only for the type they are named after and return nil otherwise,
    # matching the dotnet and Python runtimes. Coercing instead would make every reader answer for
    # every payload, which leaves a composed type unable to tell which member it holds.
    def get_string_value
      @current_node.is_a?(String) ? @current_node : nil
    end

    def get_boolean_value
      [true, false].include?(@current_node) ? @current_node : nil
    end

    def get_number_value
      @current_node.is_a?(Integer) ? @current_node : nil
    end

    # Widened to Numeric because JSON writes a whole number without a fraction, so a float field can
    # legitimately arrive as an Integer.
    def get_float_value
      @current_node.is_a?(Numeric) ? @current_node.to_f : nil
    end

    def get_guid_value
      UUIDTools::UUID.parse(@current_node) if @current_node.is_a?(String)
    end

    def get_date_value
      Date.parse(@current_node) if @current_node.is_a?(String)
    end

    def get_time_value
      Time.parse(@current_node) if @current_node.is_a?(String)
    end

    def get_date_time_value
      DateTime.parse(@current_node) if @current_node.is_a?(String)
    end

    def get_duration_value
      MicrosoftKiotaAbstractions::ISODuration.new(@current_node) if @current_node.is_a?(String)
    end

    # The generator passes the type as a class, except for booleans which it passes as a plain
    # string. A `case` cannot dispatch on that: `when String` asks whether the type is an instance
    # of String, and a class is an instance of Class, so every branch fell through to the string
    # reader. A hash keys on the class object itself.
    PRIMITIVE_READERS = {
      String => :get_string_value,
      Float => :get_float_value,
      Integer => :get_number_value,
      Date => :get_date_value,
      DateTime => :get_date_time_value,
      Time => :get_time_value,
      MicrosoftKiotaAbstractions::ISODuration => :get_duration_value,
      UUIDTools::UUID => :get_guid_value,
      'boolean' => :get_boolean_value,
      'Boolean' => :get_boolean_value
    }.freeze

    def get_collection_of_primitive_values(type)
      return unless @current_node.is_a?(Array)

      reader = PRIMITIVE_READERS[type]
      @current_node.map do |object|
        next if object.nil?
        # an untyped collection is generated as Object, which has no reader of its own; the parsed
        # JSON scalar is already the value, so it passes through rather than being stringified
        next object if reader.nil?

        JsonParseNode.new(object).public_send(reader)
      rescue StandardError => e
        raise e.class, "Failed to fetch #{type} type: #{e.message}"
      end
    end

    def get_collection_of_object_values(factory)
      raise StandardError, 'Factory cannot be null' if factory.nil?
      return unless @current_node.is_a?(Array)

      @current_node.map do |object|
        next if object.nil?

        current_parse_node = child_node(object)
        current_parse_node.get_object_value(factory)
      end
    end

    def get_object_value(factory)
      raise StandardError, 'Factory cannot be null' if factory.nil?

      item = factory.call(self)
      begin
        on_before_assign_field_values&.call(item)
        assign_field_values(item)
      ensure
        on_after_assign_field_values&.call(item)
      end
      item
    rescue StandardError => e
      raise e.class, 'Error during deserialization'
    end

    def assign_field_values(item)
      return unless @current_node.is_a?(Hash)

      fields = item.get_field_deserializers
      @current_node.each do |k, v|
        next if v.nil?

        deserializer = fields[k]
        next deserializer.call(child_node(v)) if deserializer

        additional_data = item.respond_to?(:additional_data) ? item.additional_data : nil
        next if additional_data.nil?

        additional_data[k] = v
      end
    end

    def get_enum_values(type)
      raw_values = get_string_value
      return [] if raw_values.nil? || raw_values.empty?

      raw_values.split(',').map { |raw| resolve_enum_member(type, raw.strip) }
    end

    def get_enum_value(type)
      get_enum_values(type).first
    end

    def get_collection_of_enum_values(type)
      return get_enum_values(type) if @current_node.is_a?(String)
      return unless @current_node.is_a?(Array)

      @current_node.map { |value| JsonParseNode.new(value).get_enum_value(type) }
    end

    def resolve_enum_member(type, raw)
      return raw.to_sym unless type.is_a?(Hash)

      type.each_value { |value| return value if value.to_s == raw }
      type[raw.to_sym] || type[(raw[0].to_s.upcase + raw[1..].to_s).to_sym]
    end

    def get_child_node(name)
      raise StandardError, 'Name cannot be null' if name.nil? || name.empty?

      return unless @current_node.is_a?(Hash)

      raw_value = @current_node[name]
      child_node(raw_value) if raw_value
    end

    private

    # nested nodes keep the callbacks so nested models are tracked too
    def child_node(value)
      JsonParseNode.new(value).tap do |node|
        node.on_before_assign_field_values = on_before_assign_field_values
        node.on_after_assign_field_values = on_after_assign_field_values
      end
    end
  end
end
