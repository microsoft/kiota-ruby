# frozen_string_literal: true

require 'faraday'
require_relative 'body_inspection_option'

module MicrosoftKiotaFaraday
  module Middleware
    class BodyInspectionHandler < Faraday::Middleware
      def on_request(env)
        option(env)&.capture_request_body(env.request_body)
      end

      def on_complete(env)
        option(env)&.capture_response_body(env.response_body)
      end

      private

      def option(env)
        env.request.context&.[](BodyInspectionOption::KEY)
      end
    end
  end
end
