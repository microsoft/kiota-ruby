# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  module ParseNode
    # called with the model before and after its fields are filled, see ParseNodeProxyFactory
    attr_accessor :on_before_assign_field_values, :on_after_assign_field_values

    def get_string_value
      raise NotImplementedError
    end

    def get_boolean_value
      raise NotImplementedError
    end

    def get_number_value
      raise NotImplementedError
    end

    def get_guid_value
      raise NotImplementedError
    end

    def get_date_value
      raise NotImplementedError
    end

    def get_time_value
      raise NotImplementedError
    end

    def get_date_time_value
      raise NotImplementedError
    end

    def get_duration_value
      raise NotImplementedError
    end

    def get_collection_of_primitive_values
      raise NotImplementedError
    end

    def get_collection_of_object_values(_factory)
      raise NotImplementedError
    end

    def get_object_value(_factory)
      raise NotImplementedError
    end

    def assign_field_values(_item)
      raise NotImplementedError
    end

    def get_collection_of_enum_values(_type)
      raise NotImplementedError
    end

    def get_enum_value(_type)
      raise NotImplementedError
    end

    def get_child_node(_name)
      raise NotImplementedError
    end
  end
end
