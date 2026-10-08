# frozen_string_literal: true

require 'English'
require 'delegate'
require_relative '../serialization/serialization_writer_proxy_factory'
require_relative 'backed_model'

module MicrosoftKiotaAbstractions
  # Writes only the values of a model that changed, including the ones set back to nil
  class BackingStoreSerializationWriterProxyFactory < SerializationWriterProxyFactory
    def initialize(concrete)
      super(concrete, nil, nil, nil)
    end

    def get_serialization_writer(content_type)
      session = Session.new
      writer = wrap(@concrete.get_serialization_writer(content_type),
                    session.method(:before), session.method(:after), session.method(:start))
      DocumentWriter.new(writer, session)
    end

    # the document is complete once its content is produced: only then do the written models become clean
    class DocumentWriter < SimpleDelegator
      def initialize(writer, session)
        super(writer)
        @session = session
      end

      def get_serialized_content
        content = __getobj__.get_serialized_content
        @session.finish
        content
      end
    end

    # one per writer: tracks the models written into the document
    class Session
      def initialize
        @depth = 0
        @filtering = {}.compare_by_identity
        @written = {}.compare_by_identity
        @failed = false
      end

      def before(value)
        # an exception already being handled around the write is not a failure of the write
        @outer_error = $ERROR_INFO if @depth.zero?
        @depth += 1
        store = store_of(value)
        return unless store

        @filtering[store] = store.return_only_changed_values unless @filtering.key?(store)
        store.return_only_changed_values = true
      end

      def start(value, writer)
        store_of(value)&.enumerate_keys_for_values_changed_to_nil&.each { |key| writer.write_null_value(key) }
      end

      # runs even when writing the model raised: the store reads every value again, and keeps its changes
      def after(value)
        @depth -= 1
        @failed ||= !$ERROR_INFO.nil? && !$ERROR_INFO.equal?(@outer_error)
        store = store_of(value)
        return unless store

        store.return_only_changed_values = @filtering.delete(store) if @filtering.key?(store)
        @written[store] = true
      end

      def finish
        @written.each_key { |store| store.initialization_completed = true } unless @failed
        @written.clear
        @failed = false
      end

      private

      def store_of(value)
        value.backing_store if value.is_a?(BackedModel)
      end
    end
    private_constant :DocumentWriter, :Session
  end
end
