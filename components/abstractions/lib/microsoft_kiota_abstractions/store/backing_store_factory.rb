# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  # Creates the backing store of a new model
  module BackingStoreFactory
    def create_backing_store
      raise NotImplementedError
    end
  end
end
