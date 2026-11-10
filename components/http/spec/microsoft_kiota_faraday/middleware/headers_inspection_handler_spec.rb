# frozen_string_literal: true

RSpec.describe MicrosoftKiotaFaraday::Middleware::HeadersInspectionHandler do
  let(:request_info) do
    MicrosoftKiotaAbstractions::RequestInformation.new.tap do |info|
      info.http_method = :GET
      info.uri = 'https://example.com/items'
      info.headers.add('Range', 'items=0-99')
    end
  end
  let(:auth) { MicrosoftKiotaAbstractions::AnonymousAuthenticationProvider.new }
  let(:parse_node_factory) { double('parse_node_factory') }
  let(:parse_node) { double('parse_node', get_string_value: 'items') }
  let(:stubs) do
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/items') do
        [200, { 'Content-Type' => 'application/json', 'Content-Range' => 'items 0-99/200' }, '"items"']
      end
    end
  end
  let(:client) do
    Faraday.new do |builder|
      MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware.each { |handler| builder.use handler }
      builder.adapter :test, stubs
    end
  end
  let(:adapter) { MicrosoftKiotaFaraday::FaradayRequestAdapter.new(auth, parse_node_factory, nil, client) }

  before do
    allow(parse_node_factory).to receive(:get_parse_node).with('application/json', '"items"').and_return(parse_node)
  end

  it 'exposes requested headers while still deserializing the response' do
    option = MicrosoftKiotaFaraday::Middleware::HeadersInspectionOption.new(
      inspect_request_headers: true,
      inspect_response_headers: true
    )
    request_info.add_request_options(option)

    expect(adapter.send_primitive_async(request_info, String, nil).resume).to eq('items')
    expect(option.request_headers['range']).to eq('items=0-99')
    expect(option.response_headers['content-range']).to eq('items 0-99/200')
    expect(client.options.context).to be_nil
  end

  it 'only captures headers from the enabled side' do
    option = MicrosoftKiotaFaraday::Middleware::HeadersInspectionOption.new(inspect_response_headers: true)
    request_info.add_request_options(option)

    adapter.send_primitive_async(request_info, String, nil).resume

    expect(option.request_headers).to be_empty
    expect(option.response_headers['Content-Range']).to eq('items 0-99/200')
  end
end
