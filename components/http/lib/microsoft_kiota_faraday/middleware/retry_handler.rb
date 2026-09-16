# frozen_string_literal: true

require 'faraday/retry'

module MicrosoftKiotaFaraday
  module Middleware
    class RetryHandler < Faraday::Retry::Middleware
      DEFAULT_OPTIONS = {
        max: 3,
        interval: 3,
        max_interval: 180,
        backoff_factor: 2,
        retry_statuses: [429, 503, 504]
      }.freeze

      def initialize(app, options = nil)
        super(app, DEFAULT_OPTIONS.merge(options || {}))
      end
    end
  end
end
