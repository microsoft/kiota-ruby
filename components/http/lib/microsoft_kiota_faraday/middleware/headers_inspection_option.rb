# frozen_string_literal: true

require 'faraday'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaFaraday
  module Middleware
    class HeadersInspectionOption
      include MicrosoftKiotaAbstractions::RequestOption

      KEY = 'headersInspection'

      attr_accessor :inspect_request_headers, :inspect_response_headers
      attr_reader :request_headers, :response_headers

      def initialize(inspect_request_headers: false, inspect_response_headers: false)
        @inspect_request_headers = inspect_request_headers
        @inspect_response_headers = inspect_response_headers
        @request_headers = Faraday::Utils::Headers.new
        @response_headers = Faraday::Utils::Headers.new
      end

      def get_key
        KEY
      end

      def capture(request_headers, response_headers)
        @request_headers = Faraday::Utils::Headers.new(request_headers) if inspect_request_headers
        @response_headers = Faraday::Utils::Headers.new(response_headers) if inspect_response_headers
      end
    end
  end
end
