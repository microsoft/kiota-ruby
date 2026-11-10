# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module MicrosoftKiotaFaraday
  module Middleware
    class RedirectHandlerOption
      include MicrosoftKiotaAbstractions::RequestOption

      KEY = 'redirectHandler'
      DEFAULT_MAX_REDIRECTS = 5

      attr_reader :max_redirects

      def initialize(max_redirects: DEFAULT_MAX_REDIRECTS)
        raise ArgumentError, 'max_redirects must be a non-negative integer' unless max_redirects.is_a?(Integer) && max_redirects >= 0

        @max_redirects = max_redirects
      end

      def get_key
        KEY
      end
    end
  end
end
