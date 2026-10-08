# frozen_string_literal: true

require_relative '../serialization/parse_node_proxy_factory'
require_relative 'backed_model'

module MicrosoftKiotaAbstractions
  # Marks a model's values as not changed once it has been read
  class BackingStoreParseNodeFactory < ParseNodeProxyFactory
    def initialize(concrete)
      super(concrete,
            ->(value) { value.backing_store.initialization_completed = false if value.is_a?(BackedModel) && value.backing_store },
            ->(value) { value.backing_store.initialization_completed = true if value.is_a?(BackedModel) && value.backing_store })
    end
  end
end
