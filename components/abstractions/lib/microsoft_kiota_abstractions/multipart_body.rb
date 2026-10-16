# frozen_string_literal: true

require 'securerandom'
require_relative 'serialization/parsable'

module MicrosoftKiotaAbstractions
  class MultipartBody
    include Parsable

    Part = Struct.new(:name, :content_type, :value, :filename)
    private_constant :Part

    attr_reader :boundary
    attr_accessor :request_adapter

    def initialize
      @boundary = SecureRandom.uuid
      @parts = {}
    end

    def add_or_replace_part(part_name, content_type, part_value, filename = nil)
      raise ArgumentError, 'Part name cannot be null' if blank?(part_name)
      raise ArgumentError, 'Content type cannot be null' if blank?(content_type)
      raise ArgumentError, 'Content type cannot contain line breaks' if content_type.to_s.match?(/[\r\n]/)
      raise ArgumentError, 'Part value cannot be null' if part_value.nil?

      @parts[normalize(part_name)] = Part.new(part_name, content_type, part_value, filename)
    end

    def get_part_value(part_name)
      raise ArgumentError, 'Part name cannot be null' if blank?(part_name)

      @parts[normalize(part_name)]&.value
    end

    def remove_part(part_name) # rubocop:disable Naming/PredicateMethod
      raise ArgumentError, 'Part name cannot be null' if blank?(part_name)

      !@parts.delete(normalize(part_name)).nil?
    end

    def serialize(writer)
      raise ArgumentError, 'Serialization writer cannot be null' if writer.nil?
      raise ArgumentError, 'Request adapter or serialization writer factory cannot be null' if request_adapter&.get_serialization_writer_factory.nil?
      raise ArgumentError, 'No parts to serialize' if @parts.empty?

      @parts.each_value.with_index do |part, index|
        add_new_line(writer) unless index.zero?
        writer.write_string_value('', "--#{boundary}")
        writer.write_string_value('Content-Type', part.content_type)
        writer.write_string_value('Content-Disposition', content_disposition(part))
        add_new_line(writer)
        write_part_value(writer, part)
      end
      add_new_line(writer)
      writer.write_string_value('', "--#{boundary}--")
    end

    private

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def normalize(part_name)
      part_name.downcase
    end

    def add_new_line(writer)
      writer.write_string_value('', '')
    end

    def content_disposition(part)
      disposition = %(form-data; name="#{escape(part.name)}")
      disposition += %(; filename="#{escape(part.filename)}") unless part.filename.nil?
      disposition
    end

    # as browsers escape names and file names in multipart/form-data
    def escape(value)
      value.to_s.gsub(/["\r\n]/, '"' => '%22', "\r" => '%0D', "\n" => '%0A')
    end

    def write_part_value(writer, part)
      value = part.value
      if value.is_a?(Parsable)
        writer.write_byte_array_value('', serialize_parsable(part))
      elsif value.is_a?(String)
        writer.write_byte_array_value('', value)
      elsif value.respond_to?(:read)
        rewind(value)
        writer.write_byte_array_value('', value.read)
      else
        raise ArgumentError, "Unsupported type #{value.class} for part #{part.name}"
      end
    end

    # read from the start each time the body is written, as .NET does for a seekable stream
    def rewind(stream)
      stream.rewind if stream.respond_to?(:rewind)
    rescue SystemCallError
      nil
    end

    def serialize_parsable(part)
      part_writer = request_adapter.get_serialization_writer_factory.get_serialization_writer(part.content_type)
      part_writer.write_object_value(nil, part.value)
      content = part_writer.get_serialized_content
      return content unless content.respond_to?(:read)

      content.rewind if content.respond_to?(:rewind)
      content.read
    end
  end
end
