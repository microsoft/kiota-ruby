# frozen_string_literal: true

require 'faraday'
require_relative 'headers_inspection_option'

module MicrosoftKiotaFaraday
  module Middleware
    class HeadersInspectionHandler < Faraday::Middleware
      def on_complete(env)
        option = env.request.context&.[](HeadersInspectionOption::KEY)
        option&.capture(env.request_headers, env.response_headers)
      end
    end
  end
end
