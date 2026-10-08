# frozen_string_literal: true

require_relative 'serialization_writer_factory'

module MicrosoftKiotaAbstractions
  # Wraps a serialization writer factory to run callbacks around every model it writes
  class SerializationWriterProxyFactory
    include SerializationWriterFactory

    def initialize(concrete, on_before, on_after, on_start)
      raise ArgumentError, 'concrete factory cannot be nil' if concrete.nil?

      @concrete = concrete
      @on_before = on_before
      @on_after = on_after
      @on_start = on_start
    end

    def get_valid_content_type
      @concrete.get_valid_content_type
    end

    def get_serialization_writer(content_type)
      wrap(@concrete.get_serialization_writer(content_type), @on_before, @on_after, @on_start)
    end

    protected

    def wrap(writer, on_before, on_after, on_start)
      original_before = writer.on_before_object_serialization
      original_after = writer.on_after_object_serialization
      original_start = writer.on_start_object_serialization
      writer.on_before_object_serialization = lambda do |value|
        on_before&.call(value)
        original_before&.call(value)
      end
      # after callbacks unwind the before ones, and run even when an inner one raised
      writer.on_after_object_serialization = lambda do |value|
        original_after&.call(value)
      ensure
        on_after&.call(value)
      end
      writer.on_start_object_serialization = lambda do |value, object_writer|
        on_start&.call(value, object_writer)
        original_start&.call(value, object_writer)
      end
      writer
    end
  end
end
