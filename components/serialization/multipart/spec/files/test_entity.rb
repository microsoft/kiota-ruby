# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module Files
  class TestEntity
    include MicrosoftKiotaAbstractions::Parsable
    include MicrosoftKiotaAbstractions::AdditionalDataHolder

    attr_accessor :id, :display_name, :birthday, :work_duration, :additional_data

    def initialize
      @additional_data = {}
    end

    def get_field_deserializers
      {}
    end

    def serialize(writer)
      writer.write_guid_value('id', @id)
      writer.write_string_value('displayName', @display_name)
      writer.write_date_value('birthDay', @birthday)
      writer.write_duration_value('workDuration', @work_duration)
      writer.write_additional_data(@additional_data)
    end
  end
end
