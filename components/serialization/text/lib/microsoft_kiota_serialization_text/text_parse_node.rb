# frozen_string_literal: true

require 'time'
require 'date'
require 'uuidtools'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaSerializationText
  class TextParseNode
    include MicrosoftKiotaAbstractions::ParseNode

    NO_STRUCTURED_DATA_MESSAGE = 'Text does not support structured data'

    # temporal readers take only their own shape, as in the form gem, so a union picks the right member
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    TIME = /\A\d{2}:\d{2}(:\d{2}(\.\d+)?)?\z/
    DATE_TIME = /\A\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?([Zz]|[+-]\d{2}(:?\d{2})?)?\z/

    def initialize(text)
      @text = text
    end

    def get_string_value
      @text unless @text.nil? || @text.empty?
    end

    def get_boolean_value
      case scalar_text&.downcase
      when 'true' then true
      when 'false' then false
      end
    end

    def get_number_value
      text = scalar_text
      Integer(text, 10, exception: false) if text
    end

    def get_float_value
      text = scalar_text
      Float(text, exception: false) if text
    end

    def get_guid_value
      parsed { |text| UUIDTools::UUID.parse(text) }
    end

    def get_date_value
      parsed { |text| Date.parse(text) if DATE.match?(text) }
    end

    def get_time_value
      parsed { |text| Time.parse(text) if TIME.match?(text) }
    end

    def get_date_time_value
      parsed { |text| DateTime.parse(text) if DATE_TIME.match?(text) }
    end

    def get_duration_value
      parsed { |text| MicrosoftKiotaAbstractions::ISODuration.new(text) }
    end

    def get_byte_array_value
      scalar_text&.unpack1('m')
    end

    def get_enum_value(type)
      text = scalar_text
      resolve_enum_member(type, text) if text
    end

    def get_child_node(_name)
      raise StandardError, NO_STRUCTURED_DATA_MESSAGE
    end

    def get_collection_of_primitive_values(_type)
      raise StandardError, NO_STRUCTURED_DATA_MESSAGE
    end

    def get_collection_of_object_values(_factory)
      raise StandardError, NO_STRUCTURED_DATA_MESSAGE
    end

    def get_collection_of_enum_values(_type)
      raise StandardError, NO_STRUCTURED_DATA_MESSAGE
    end

    def get_object_value(_factory)
      raise StandardError, NO_STRUCTURED_DATA_MESSAGE
    end

    private

    # text that does not parse reads as nil, as .NET's TryParse and the form gem do
    def parsed
      text = scalar_text
      yield text if text
    rescue StandardError
      nil
    end

    # typed values ignore surrounding whitespace, as .NET's TryParse does
    def scalar_text
      text = get_string_value&.strip
      text unless text.nil? || text.empty?
    end

    # same resolution as JsonParseNode: the wire value first, then the member name
    def resolve_enum_member(type, raw)
      return raw.to_sym unless type.is_a?(Hash)

      type.each_value { |value| return value if value.to_s == raw }
      type[raw.to_sym] || type[(raw[0].to_s.upcase + raw[1..].to_s).to_sym]
    end
  end
end
