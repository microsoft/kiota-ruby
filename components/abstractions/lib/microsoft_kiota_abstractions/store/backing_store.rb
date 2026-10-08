# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  # Stores the values of a model and tracks which ones changed since it was read
  module BackingStore
    def get(_key)
      raise NotImplementedError
    end

    def set(_key, _value)
      raise NotImplementedError
    end

    # the stored key and value pairs, or only the changed ones when return_only_changed_values is set
    def enumerate
      raise NotImplementedError
    end

    def enumerate_keys_for_values_changed_to_nil
      raise NotImplementedError
    end

    # registers a callback called with (key, old_value, new_value) on every set, returns its id
    def subscribe(_callback, _subscription_id = nil)
      raise NotImplementedError
    end

    def unsubscribe(_subscription_id)
      raise NotImplementedError
    end

    def clear
      raise NotImplementedError
    end

    def initialization_completed
      raise NotImplementedError
    end

    def initialization_completed=(_value)
      raise NotImplementedError
    end

    def return_only_changed_values
      raise NotImplementedError
    end

    def return_only_changed_values=(_value)
      raise NotImplementedError
    end
  end
end
