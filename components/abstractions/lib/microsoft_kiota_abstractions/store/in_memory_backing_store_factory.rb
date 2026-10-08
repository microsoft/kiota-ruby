# frozen_string_literal: true

require_relative 'backing_store_factory'
require_relative 'in_memory_backing_store'

module MicrosoftKiotaAbstractions
  # Creates in memory backing stores
  class InMemoryBackingStoreFactory
    include BackingStoreFactory

    def create_backing_store
      InMemoryBackingStore.new
    end
  end
end
