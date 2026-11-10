# frozen_string_literal: true

require 'stringio'
require 'microsoft_kiota_abstractions'

module MicrosoftKiotaFaraday
  module Middleware
    # Opt in per request. The caller owns and should close each in-memory copy.
    # Capturing large payloads increases memory use; non-seekable streams are skipped.
    class BodyInspectionOption
      include MicrosoftKiotaAbstractions::RequestOption

      KEY = 'bodyInspection'
      attr_accessor :inspect_request_body, :inspect_response_body
      attr_reader :request_body, :response_body

      def initialize(inspect_request_body: false, inspect_response_body: false)
        @inspect_request_body = inspect_request_body
        @inspect_response_body = inspect_response_body
      end

      def get_key
        KEY
      end

      def capture_request_body(body)
        @request_body = inspect_request_body ? copy_body(body) : nil
      end

      def capture_response_body(body)
        @response_body = inspect_response_body ? copy_body(body) : nil
      end

      private

      def copy_body(body)
        return StringIO.new(body.dup) if body.is_a?(String)
        return unless body.respond_to?(:read) && body.respond_to?(:pos) && body.respond_to?(:pos=)

        position = seekable_position(body)
        return if position.nil?

        begin
          StringIO.new(body.read || +'')
        ensure
          body.pos = position
        end
      end

      def seekable_position(body)
        position = body.pos
        body.pos = position
        position
      rescue Errno::ESPIPE, Errno::EINVAL, IOError
        nil
      end
    end
  end
end
