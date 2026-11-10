# frozen_string_literal: true

require 'stringio'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RedirectHandler do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) do
    Faraday.new('https://example.com') do |builder|
      MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware.each { |handler| builder.use handler }
      builder.adapter :test, stubs
    end
  end

  def set_redirect_limit(request, limit)
    option = MicrosoftKiotaFaraday::Middleware::RedirectHandlerOption.new(max_redirects: limit)
    request.options.context = { option.get_key => option }
  end

  it 'resolves each relative location and keeps same-origin credentials and context' do
    stubs.get('/one/start') { [301, { 'Location' => 'two/next' }, ''] }
    stubs.get('/one/two/next') { [302, { 'Location' => '../final?item=1#part' }, ''] }
    stubs.get('/one/final?item=1') do |env|
      expect(env.request_headers['Authorization']).to eq('Bearer token')
      expect(env.request.context[:sentinel]).to eq(:kept)
      expect(env.url.fragment).to be_nil
      [200, {}, 'done']
    end

    response = client.get('/one/start', nil, 'Authorization' => 'Bearer token') do |request|
      request.options.context = { sentinel: :kept }
    end

    expect(response.body).to eq('done')
    stubs.verify_stubbed_calls
  end

  it 'strips origin credentials on a port change and does not restore them on return' do
    stubs.get('/start') { [302, { 'Location' => 'https://example.com:8443/other' }, ''] }
    stubs.get('/other') do |env|
      expect(env.url.port).to eq(8443)
      expect(env.request_headers.keys & %w[Authorization Cookie Proxy-Authorization Host]).to be_empty
      expect(env.request_headers['Accept']).to eq('text/plain')
      [302, { 'Location' => 'https://example.com/end' }, '']
    end
    stubs.get('/end') do |env|
      expect(env.request_headers['Authorization']).to be_nil
      [200, {}, 'done']
    end
    headers = {
      'authorization' => 'Bearer token', 'cookie' => 'secret=value', 'proxy-authorization' => 'Basic secret',
      'host' => 'example.com', 'accept' => 'text/plain'
    }

    expect(client.get('/start', nil, headers).status).to eq(200)
    stubs.verify_stubbed_calls
  end

  it 'replays the same remaining binary bytes on 307 and 308' do
    payload = "\x00\xffrest".b
    stream = StringIO.new('used'.b + payload)
    stream.read(4)
    [307, 308, 200].each_with_index do |status, index|
      stubs.put("/upload/#{index}") do |env|
        expect(env.body).to eq(payload)
        expect(env.request_headers['Content-Length']).to eq(payload.bytesize.to_s)
        expect(env.request_headers['Transfer-Encoding']).to be_nil
        [status, { 'Location' => "/upload/#{index + 1}" }, '']
      end
    end

    expect(client.put('/upload/0', stream, 'Transfer-Encoding' => 'chunked').status).to eq(200)
    stubs.verify_stubbed_calls
  end

  it 'does not follow cross-origin redirects with a client certificate configured' do
    client.ssl.client_cert = OpenSSL::X509::Certificate.new
    stubs.get('/start') { [302, { 'Location' => '/same-origin' }, ''] }
    stubs.get('/same-origin') { [302, { 'Location' => 'https://other.example/end' }, 'stop'] }

    expect(client.get('/start').body).to eq('stop')
    stubs.verify_stubbed_calls
  end

  [301, 302, 303].each do |status|
    it "changes POST to GET and drops body headers on #{status}" do
      stubs.post('/submit') { [status, { 'Location' => '/result' }, ''] }
      stubs.get('/result') do |env|
        expect(env.body).to be_nil
        expect(env.request_headers.keys & %w[Content-Length Content-Type Content-Encoding]).to be_empty
        [200, {}, 'result']
      end

      headers = { 'Content-Length' => '4', 'Content-Type' => 'text/plain', 'Content-Encoding' => 'identity' }
      expect(client.post('/submit', 'body', headers).body).to eq('result')
      stubs.verify_stubbed_calls
    end
  end

  it 'keeps HEAD on 303' do
    stubs.head('/start') { [303, { 'Location' => '/end' }, ''] }
    stubs.head('/end') { [200, {}, ''] }

    expect(client.head('/start').status).to eq(200)
    stubs.verify_stubbed_calls
  end

  it 'returns the last redirect response after reaching the per-request limit' do
    stubs.get('/one') { [302, { 'Location' => '/two' }, 'first'] }
    stubs.get('/two') { [302, { 'Location' => '/three' }, 'second'] }

    response = client.get('/one') { |request| set_redirect_limit(request, 1) }

    expect(response.status).to eq(302)
    expect(response.body).to eq('second')
    stubs.verify_stubbed_calls
  end

  it 'buffers and replays an upload from a non-seekable pipe' do
    IO.pipe do |reader, writer|
      writer.write('streamed body')
      writer.close
      stubs.put('/upload') { [307, { 'Location' => '/other' }, ''] }
      stubs.put('/other') do |env|
        expect(env.body).to eq('streamed body')
        [200, {}, '']
      end

      expect(client.put('/upload', reader).status).to eq(200)
    end
    stubs.verify_stubbed_calls
  end

  it 'leaves a non-seekable upload untouched when redirects are disabled' do
    IO.pipe do |reader, writer|
      writer.write('streamed body')
      writer.close
      stubs.put('/upload') do |env|
        expect(env.body).to be(reader)
        expect(reader.read).to eq('streamed body')
        [307, { 'Location' => '/other' }, '']
      end

      response = client.put('/upload', reader) { |request| set_redirect_limit(request, 0) }
      expect(response.status).to eq(307)
    end
    stubs.verify_stubbed_calls
  end

  [nil, ' ', 'http://example.com/unsafe', 'ftp://example.com/file', 'https://user@example.com/path', '/bad path'].each do |location|
    it "returns the original response for unusable Location #{location.inspect}" do
      headers = location ? { 'Location' => location } : {}
      stubs.get('/start') { [302, headers, 'original'] }

      response = client.get('/start')

      expect(response.status).to eq(302)
      expect(response.body).to eq('original')
    end
  end
end
