# frozen_string_literal: true

require 'stringio'

RSpec.describe MicrosoftKiotaFaraday::FaradayRequestAdapter do
  subject(:adapter) { described_class.new(authentication_provider, nil, nil, client) }

  let(:authentication_provider) { double('authentication_provider') }
  let(:client) { double('client') }

  let(:request_info) do
    info = MicrosoftKiotaAbstractions::RequestInformation.new
    info.http_method = :PUT
    info.url_template = '{+baseurl}/files'
    info.path_parameters = { 'baseurl' => 'https://example.com' }
    info
  end

  before do
    allow(client).to receive(:build_request).and_return(Faraday::Request.create(:put))
  end

  it 'sends a stream body without reading it into memory' do
    stream = StringIO.new('rawbytes')
    request_info.set_stream_content(stream, 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.body).to be(stream)
    expect(request.headers['Content-Length']).to eq('8')
    expect(stream.pos).to be_zero
  end

  it 'measures a stream that has already been partially read' do
    stream = StringIO.new('rawbytes')
    stream.read(3)
    request_info.set_stream_content(stream, 'application/octet-stream')
    expect(adapter.get_request_from_request_info(request_info).headers['Content-Length']).to eq('5')
  end

  it 'sends a stream of unknown length chunked' do
    reader, writer = IO.pipe
    writer.write('rawbytes')
    writer.close
    request_info.set_stream_content(reader, 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.headers['Transfer-Encoding']).to eq('chunked')
    expect(request.headers['Content-Length']).to be_nil
  end

  it 'omits an empty stream body' do
    request_info.set_stream_content(StringIO.new(''), 'application/octet-stream')
    expect(adapter.get_request_from_request_info(request_info).body).to be_nil
  end

  it 'drops a caller supplied Content-Length when the body has to be chunked' do
    reader, writer = IO.pipe
    writer.write('rawbytes')
    writer.close
    request_info.headers.add('Content-Length', '99')
    request_info.set_stream_content(reader, 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.headers['Transfer-Encoding']).to eq('chunked')
    expect(request.headers['Content-Length']).to be_nil
  end

  it 'drops a caller supplied Transfer-Encoding when the length is known' do
    request_info.headers.add('Transfer-Encoding', 'chunked')
    request_info.set_stream_content(StringIO.new('rawbytes'), 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.headers['Content-Length']).to eq('8')
    expect(request.headers['Transfer-Encoding']).to be_nil
  end

  it 'clears stale framing headers for an empty stream' do
    request_info.headers.add('Content-Length', '99')
    request_info.headers.add('Transfer-Encoding', 'chunked')
    request_info.set_stream_content(StringIO.new(''), 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.body).to be_nil
    expect(request.headers['Content-Length']).to be_nil
    expect(request.headers['Transfer-Encoding']).to be_nil
  end

  it 'clears stale framing headers for an empty string body' do
    request_info.headers.add('Content-Length', '99')
    request_info.set_stream_content('', 'application/json')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.body).to be_nil
    expect(request.headers['Content-Length']).to be_nil
  end

  it 'clears stale framing headers when there is no body at all' do
    request_info.headers.add('Content-Length', '99')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.headers['Content-Length']).to be_nil
  end

  it 'treats a stream positioned past its end as empty' do
    stream = StringIO.new('rawbytes')
    stream.seek(100)
    request_info.headers.add('Content-Length', '99')
    request_info.set_stream_content(stream, 'application/octet-stream')
    request = adapter.get_request_from_request_info(request_info)
    expect(request.body).to be_nil
    expect(request.headers['Content-Length']).to be_nil
  end

  it 'sends a body that does not answer to empty?' do
    request_info.set_stream_content(42, 'application/json')
    expect(adapter.get_request_from_request_info(request_info).body).to eq(42)
  end

  it 'still sends a string body' do
    request_info.set_stream_content('{"a":1}', 'application/json')
    expect(adapter.get_request_from_request_info(request_info).body).to eq('{"a":1}')
  end

  it 'still omits an empty string body' do
    request_info.set_stream_content('', 'application/json')
    expect(adapter.get_request_from_request_info(request_info).body).to be_nil
  end
end
