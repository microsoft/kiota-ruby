# frozen_string_literal: true

require_relative 'in_memory_backing_store_factory'

module MicrosoftKiotaAbstractions
  # Holds the backing store factory generated models use
  module BackingStoreFactorySingleton
    class << self
      attr_writer :instance

      def instance
        @instance ||= InMemoryBackingStoreFactory.new
      end
    end
  end
end
