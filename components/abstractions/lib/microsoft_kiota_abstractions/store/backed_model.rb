# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  # A model that keeps its values in a backing store
  module BackedModel
    attr_reader :backing_store
  end
end
