# frozen_string_literal: true

module MicrosoftKiotaFaraday
  # Faraday sends an IO body as a Net::HTTP body_stream, which needs its length up front, so a
  # stream is passed through and measured rather than read into memory.
  module RequestBody
    FRAMING_HEADERS = %w[Content-Length Transfer-Encoding].freeze

    module_function

    def apply(request, content)
      # the request owns its framing, so whatever the caller sent is dropped and then set from the
      # body that is actually written, which leaves every early return below safe
      FRAMING_HEADERS.each { |header| request.headers.delete(header) }
      return if content.nil?

      unless content.respond_to?(:read)
        request.body = content unless content.respond_to?(:empty?) && content.empty?
        return
      end

      length = stream_length(content)
      return if length&.zero?

      if length.nil?
        request.headers['Transfer-Encoding'] = 'chunked'
      else
        request.headers['Content-Length'] = length.to_s
      end
      request.body = content
    end

    # a stream that cannot report a size, such as a pipe or $stdin, is sent chunked instead
    def stream_length(content)
      return nil unless content.respond_to?(:size) && content.respond_to?(:pos)

      size = content.size
      # a stream can be positioned past its end, which leaves nothing to send rather than a
      # negative number of bytes
      size.nil? ? nil : [size - content.pos, 0].max
    rescue StandardError
      nil
    end
  end
end
