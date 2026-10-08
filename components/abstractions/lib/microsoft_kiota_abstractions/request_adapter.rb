# frozen_string_literal: true

require_relative 'request_information'

module MicrosoftKiotaAbstractions
  module RequestAdapter
    def send_async(_request_info, _factory, _errors_mapping)
      raise NotImplementedError
    end

    def send_collection_async(_request_info, _factory, _errors_mapping)
      raise NotImplementedError
    end

    def send_collection_of_primitive_async(_request_info, _type, _errors_mapping)
      raise NotImplementedError
    end

    def send_primitive_async(_request_info, _type, _errors_mapping)
      raise NotImplementedError
    end

    def send_no_response_content_async(_request_info, _errors_mapping)
      raise NotImplementedError
    end

    def get_serialization_writer_factory
      raise NotImplementedError
    end

    # enables the backing store on the models this adapter reads and writes
    def enable_backing_store(_backing_store_factory = nil)
      raise NotImplementedError
    end

    def set_base_url(_base_url)
      raise NotImplementedError
    end

    def get_base_url
      raise NotImplementedError
    end

    # Converts the given RequestInformation into a native HTTP request.
    def convert_to_native_request_async(_request_info)
      raise NotImplementedError
    end
  end
end
