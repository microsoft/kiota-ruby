# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  module HttpMethod
    HTTP_METHOD = {
      GET: :GET,
      POST: :POST,
      PATCH: :PATCH,
      DELETE: :DELETE,
      OPTIONS: :OPTIONS,
      CONNECT: :CONNECT,
      PUT: :PUT,
      TRACE: :TRACE,
      HEAD: :HEAD,
      QUERY: :QUERY
    }.freeze
  end
end
