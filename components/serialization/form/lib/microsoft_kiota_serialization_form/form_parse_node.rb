# frozen_string_literal: true

require 'date'
require 'time'
require 'uri'
require 'uuidtools'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationForm
  class FormParseNode
    include MicrosoftKiotaAbstractions::ParseNode

    # temporal readers take only their own shape, as in Go, so a union picks the right member
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    TIME = /\A\d{2}:\d{2}(:\d{2}(\.\d+)?)?\z/
    DATE_TIME = /\A\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?([Zz]|[+-]\d{2}(:?\d{2})?)?\z/

    READERS = {
      string: ->(value) { value },
      boolean: ->(value) { { 'true' => true, 'false' => false }[value.downcase] },
      number: ->(value) { Integer(value, 10) },
      float: ->(value) { Float(value) },
      guid: ->(value) { UUIDTools::UUID.parse(value) },
      date: ->(value) { Date.parse(value) if DATE.match?(value) },
      time: ->(value) { Time.parse(value) if TIME.match?(value) },
      date_time: ->(value) { DateTime.parse(value) if DATE_TIME.match?(value) },
      duration: ->(value) { MicrosoftKiotaAbstractions::ISODuration.new(value) },
      byte_array: ->(value) { value.unpack1('m0') }
    }.freeze

    # keyed by the constant the generator passes; an untyped collection arrives as Object
    PRIMITIVE_TYPES = {
      String => :string,
      Object => :string,
      Integer => :number,
      Float => :float,
      UUIDTools::UUID => :guid,
      Date => :date,
      DateTime => :date_time,
      Time => :time,
      MicrosoftKiotaAbstractions::ISODuration => :duration,
      'boolean' => :boolean,
      'Boolean' => :boolean
    }.freeze

    def initialize(raw_value, raw_items = nil)
      raw_value = raw_value.to_s.b
      @raw_value = raw_value
      @value = decode(raw_value)
      @fields = parse_fields(raw_value)
      @raw_items = raw_items
    end

    # an empty value is an empty string, as .NET reads it; only null is nil
    def get_string_value
      @value unless @value == 'null'
    end

    def get_boolean_value = read(:boolean)

    def get_number_value = read(:number)

    def get_float_value = read(:float)

    def get_guid_value = read(:guid)

    def get_date_value = read(:date)

    def get_time_value = read(:time)

    def get_date_time_value = read(:date_time)

    def get_duration_value = read(:duration)

    def get_byte_array_value = read(:byte_array)

    def get_collection_of_primitive_values(type)
      raise StandardError, 'Primitive type for deserialization cannot be null' if type.nil?

      kind = PRIMITIVE_TYPES[type]
      raise StandardError, "Encountered an unknown type during deserialization #{type}" if kind.nil?

      primitive_items.map { |item| read(kind, item) }
    end

    def get_collection_of_object_values(_factory)
      raise StandardError, 'Collection of object values is not supported with uri form encoding.'
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
    end

    def assign_field_values(item)
      deserializers = item.get_field_deserializers
      by_lower_name = deserializers.transform_keys(&:downcase)
      additional_data = item.respond_to?(:additional_data) ? item.additional_data : nil
      @fields.each_value do |key, raw_values|
        deserializer = deserializers[key] || by_lower_name[key.downcase]
        value = decode(raw_values.join(','))
        if deserializer
          deserializer.call(child_node(raw_values)) unless value == 'null'
        elsif additional_data
          additional_data[key] = value
        end
      end
    end

    def get_enum_value(type)
      get_enum_values(type).first
    end

    def get_enum_values(type)
      items.map { |value| enum_member(type, value) unless blank?(value) }
    end

    alias get_collection_of_enum_values get_enum_values

    def get_child_node(name)
      raise StandardError, 'Name cannot be null' if name.nil? || name.empty?

      field = @fields[name.downcase]
      child_node(field[1]) if field
    end

    private

    # a stray % is kept as is, like Python's unquote_plus
    def decode(value)
      URI.decode_www_form_component(value.gsub(/%(?!\h\h)/, '%25')).scrub
    end

    def blank?(value)
      value.nil? || value.empty? || value == 'null'
    end

    def read(kind, value = @value)
      return if blank?(value)

      READERS.fetch(kind).call(value)
    rescue StandardError
      nil
    end

    # the items of a repeated key stay apart; a single value is split on commas
    def items
      return @raw_items.map { |raw| decode(raw) } if @raw_items && @raw_items.size > 1

      @value.split(',')
    end

    # only a comma sent as is separates primitive items; the writer encodes one inside an item
    def primitive_items
      (@raw_items || [@raw_value]).flat_map { |raw| raw.split(',') }.map { |raw| decode(raw) }
    end

    def parse_fields(raw)
      fields = {}
      raw.split('&').each do |pair|
        next unless pair.include?('=')

        key, value = pair.split('=', 2)
        key = decode(key)
        (fields[key.downcase] ||= [key, []])[1] << value
      end
      fields
    end

    def child_node(raw_values)
      FormParseNode.new(raw_values.join(','), raw_values).tap do |node|
        node.on_before_assign_field_values = on_before_assign_field_values
        node.on_after_assign_field_values = on_after_assign_field_values
      end
    end

    # same resolution as JsonParseNode: the wire value first, then the member name
    def enum_member(type, value)
      return value.to_sym unless type.is_a?(Hash)

      type.each_value { |member| return member if member.to_s == value }
      type[value.to_sym] || type[(value[0].to_s.upcase + value[1..].to_s).to_sym]
    end
  end
end
