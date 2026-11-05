# frozen_string_literal: true

# rubocop:disable-next Metrics/BlockLength
RSpec.describe MicrosoftKiotaFaraday::FaradayRequestAdapter do
  subject(:adapter) { described_class.new(authentication_provider) }

  let(:authentication_provider) { double('authentication_provider') }
  let(:headers) { { 'content-type' => 'application/json' } }
  let(:body) { { key: 'value' }.to_json }

  describe '#throw_if_failed_reponse' do
    subject(:adapter) { described_class.new(authentication_provider, parse_node_factory) }

    let(:parse_node_factory) { double('parse_node_factory') }
    let(:parse_node) { double('parse_node') }
    let(:error) { MicrosoftKiotaAbstractions::ApiError.new('bad name') }
    let(:factory) { ->(_pn) { error } }
    let(:response) { instance_double(Faraday::Response, status: 400, body:, headers:) }

    before do
      allow(parse_node_factory).to receive(:get_parse_node).with('application/json', body).and_return(parse_node)
      allow(parse_node).to receive(:get_object_value).with(factory).and_return(error)
    end

    it 'matches an exact status code keyed as a String, the way generated clients write it' do
      expect { adapter.throw_if_failed_reponse(response, { '400' => factory }) }
        .to raise_error(error)
    end

    it 'still matches a wildcard key' do
      expect { adapter.throw_if_failed_reponse(response, { '4XX' => factory }) }
        .to raise_error(error)
    end

    it 'raises a generic ApiError when nothing matches' do
      expect { adapter.throw_if_failed_reponse(response, { '404' => factory }) }
        .to raise_error(MicrosoftKiotaAbstractions::ApiError, /no error factory is registered/)
    end

    it 'picks the 5XX factory, not the 4XX one, for a 500' do
      server_error = MicrosoftKiotaAbstractions::ApiError.new('server')
      allow(parse_node).to receive(:get_object_value).and_return(server_error)
      failed = instance_double(Faraday::Response, status: 500, body:, headers:)
      expect { adapter.throw_if_failed_reponse(failed, { '4XX' => factory, '5XX' => ->(_pn) { server_error } }) }
        .to raise_error(server_error)
    end

    it 'does not use a 4XX factory for a 500' do
      failed = instance_double(Faraday::Response, status: 500, body:, headers:)
      expect { adapter.throw_if_failed_reponse(failed, { '4XX' => factory }) }
        .to raise_error(MicrosoftKiotaAbstractions::ApiError, /no error factory is registered/)
    end

    it 'returns without raising for a successful response' do
      ok = instance_double(Faraday::Response, status: 200, body:, headers:)
      expect { adapter.throw_if_failed_reponse(ok, {}) }.not_to raise_error
    end

    it 'gives the deserialized error the response status code and headers' do
      expect { adapter.throw_if_failed_reponse(response, { '400' => factory }) }.to raise_error(error) do |raised|
        expect(raised.response_status_code).to eq(400)
        expect(raised.response_headers).to eq(headers)
      end
    end

    it 'gives the generic error the response status code and headers' do
      expect { adapter.throw_if_failed_reponse(response, {}) }.to raise_error(MicrosoftKiotaAbstractions::ApiError) do |raised|
        expect(raised.response_status_code).to eq(400)
        expect(raised.response_headers).to eq(headers)
      end
    end

    it 'gives the error raised for an empty body the response status code and headers' do
      empty = instance_double(Faraday::Response, status: 503, body: '', headers:)
      expect { adapter.throw_if_failed_reponse(empty, { '5XX' => factory }) }.to raise_error(MicrosoftKiotaAbstractions::ApiError) do |raised|
        expect(raised.response_status_code).to eq(503)
        expect(raised.response_headers).to eq(headers)
      end
    end

    it 'falls back to ApiError with status and headers when failed response has no content type' do
      no_content_type = instance_double(Faraday::Response, status: 500, body: 'Internal Server Error', headers: {})
      expect { adapter.throw_if_failed_reponse(no_content_type, { '5XX' => factory }) }.to raise_error(MicrosoftKiotaAbstractions::ApiError) do |raised|
        expect(raised.response_status_code).to eq(500)
        expect(raised.response_headers).to eq({})
      end
    end
  end

  describe '#get_request_from_request_info' do
    let(:request_info) do
      MicrosoftKiotaAbstractions::RequestInformation.new.tap do |info|
        info.http_method = :QUERY
        info.uri = 'https://example.com/items'
      end
    end

    it 'builds a native QUERY request' do
      expect(adapter.client).to receive(:build_request).with(:query).and_call_original

      expect(adapter.get_request_from_request_info(request_info).http_method).to eq(:query)
    end

    it 'populates request options into context even when options context is initially nil' do
      opt = MicrosoftKiotaFaraday::Middleware::UserAgentOption.new
      request_info.add_request_options(opt)
      native_request = Faraday::Request.create(:query)
      native_request.options = Faraday::RequestOptions.new
      allow(adapter.client).to receive(:build_request).and_return(native_request)

      req = adapter.get_request_from_request_info(request_info)
      expect(req.options.context[opt.get_key]).to eq(opt)
    end
  end

  describe '#execute_async with ResponseHandlerOption' do
    let(:request_info) do
      MicrosoftKiotaAbstractions::RequestInformation.new.tap do |info|
        info.http_method = :GET
        info.uri = 'https://example.com/items'
      end
    end
    let(:response) { instance_double(Faraday::Response, status: 500, body: '{"error":"test"}', headers: {}) }

    it 'delegates to custom response handler and returns its result without throwing on error' do
      custom_option = MicrosoftKiotaFaraday::Middleware::ResponseHandlerOption.new
      custom_option.async_callback = lambda do |res|
        Fiber.new { "handled_#{res.status}" }
      end
      request_info.add_request_options(custom_option)

      allow(authentication_provider).to receive(:authenticate_request).with(request_info).and_return(Fiber.new { nil })
      allow(adapter.client).to receive(:run_request).and_return(response)

      fiber = adapter.send_async(request_info, ->(_pn) {}, nil)
      expect(fiber.resume).to eq('handled_500')
    end
  end

  describe '#convert_to_native_request_async' do
    let(:request_info) do
      MicrosoftKiotaAbstractions::RequestInformation.new.tap do |info|
        info.http_method = :GET
        info.uri = 'https://example.com/items'
      end
    end

    it 'raises when request_info is null' do
      expect { adapter.convert_to_native_request_async(nil) }.to raise_error(StandardError, 'request_info cannot be null')
    end

    it 'converts request information to a native Faraday request without LocalJumpError' do
      allow(authentication_provider).to receive(:authenticate_request).with(request_info).and_return(Fiber.new { nil })
      fiber = adapter.convert_to_native_request_async(request_info)
      native_request = fiber.resume

      expect(native_request).to be_a(Faraday::Request)
      expect(native_request.http_method).to eq(:get)
      expect(native_request.path).to eq(URI('https://example.com/items'))
    end

    it 'converts request with numeric and symbol header keys without error' do
      allow(authentication_provider).to receive(:authenticate_request).with(request_info).and_return(Fiber.new { nil })
      request_info.headers.add(123, 'numeric-header-val')
      request_info.headers.add(:custom_symbol, 'symbol-header-val')

      fiber = adapter.convert_to_native_request_async(request_info)
      native_request = fiber.resume

      expect(native_request).to be_a(Faraday::Request)
      expect(native_request.headers['123']).to eq('numeric-header-val')
      expect(native_request.headers['custom_symbol']).to eq('symbol-header-val')
    end
  end

  describe '#get_root_parse_node' do
    context 'when response is null' do
      it 'raises an error' do
        expect { adapter.get_root_parse_node(nil) }.to raise_error(StandardError, 'response cannot be null')
      end
    end

    context 'when response content type is not found' do
      let(:response) { instance_double(Faraday::Response, body:, headers: {}) }

      it 'raises an error' do
        expect do
          adapter.get_root_parse_node(response)
        end.to raise_error(StandardError,
                           'no response content type found for deserialization')
      end
    end

    context 'when response body is nil' do
      let(:response) { instance_double(Faraday::Response, body: nil, headers:) }

      it 'returns nil' do
        expect(adapter.get_root_parse_node(response)).to be_nil
      end
    end

    context 'when response body is empty' do
      let(:response) { instance_double(Faraday::Response, body: '', headers:) }

      it 'returns nil' do
        expect(adapter.get_root_parse_node(response)).to be_nil
      end
    end

    context 'when response body is not nil' do
      subject(:adapter) { described_class.new(authentication_provider, parse_node_factory) }

      let(:response) { instance_double(Faraday::Response, body:, headers:) }
      let(:parse_node_factory) { double('parse_node_factory') }
      let(:parse_node) { double('parse_node') }

      before do
        allow(parse_node_factory).to receive(:get_parse_node).with('application/json', body).and_return(parse_node)
      end

      it 'returns the parse node' do
        expect(adapter.get_root_parse_node(response)).to eq(parse_node)
      end
    end
  end
end
