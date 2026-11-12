# frozen_string_literal: true

require 'stringio'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  let(:option_class) { MicrosoftKiotaFaraday::Middleware::RetryHandlerOption }
  let(:app) { double('app') }
  let(:handler) { described_class.new(app, option_class.new(delay: 0)) }
  let(:success) { Faraday::Response.new(status: 200, body: 'ok') }

  before { allow(handler).to receive(:sleep) }

  it 'drains and closes a failed streaming response before sending the retry' do
    stream = StringIO.new('unavailable')
    failed = Faraday::Response.new(status: 503, response_headers: {}, body: stream)
    calls = 0
    allow(app).to receive(:call) do
      calls += 1
      if calls == 1
        failed
      else
        expect(stream).to be_closed
        success
      end
    end

    expect(handler.call(body: nil, request_headers: {})).to eq(success)
    expect(stream).to be_closed
    expect(failed.body).to eq('unavailable')
  end

  it 'closes a failed response stream even when reading it raises' do
    stream = double('stream', close: nil)
    allow(stream).to receive(:read).and_raise(IOError, 'read failed')
    failed = Faraday::Response.new(status: 503, response_headers: {}, body: stream)
    allow(app).to receive(:call).and_return(failed)

    expect { handler.call(body: nil, request_headers: {}) }.to raise_error(IOError, 'read failed')
    expect(stream).to have_received(:close)
    expect(app).to have_received(:call).once
  end

  it 'leaves the final response stream open when the delay budget prevents another retry' do
    stream = StringIO.new('unavailable')
    failed = Faraday::Response.new(status: 503, response_headers: {}, body: stream)
    allow(app).to receive(:call).and_return(failed)
    limited = described_class.new(app, option_class.new(delay: 3, retries_time_limit: 1))

    expect(limited.call(body: nil, request_headers: {})).to eq(failed)
    expect(stream).not_to be_closed
    expect(stream.pos).to eq(0)
  end

  [Errno::ESPIPE, Errno::EPIPE, IOError].each do |error_class|
    it "does not replay a request when seek raises #{error_class}" do
      body = double('request stream', read: 'data', pos: 0)
      allow(body).to receive(:seek).and_raise(error_class)
      failed = Faraday::Response.new(status: 503, response_headers: {}, body: 'unavailable')
      allow(app).to receive(:call).and_return(failed)

      expect(handler.call(body: body, request_headers: {})).to eq(failed)
      expect(app).to have_received(:call).once
      expect(handler).not_to have_received(:sleep)
    end
  end

  it 'does not replay a readable request body without rewind' do
    body = double('request stream', read: 'data')
    failed = Faraday::Response.new(status: 503, response_headers: {}, body: 'unavailable')
    allow(app).to receive(:call).and_return(failed)

    expect(handler.call(body: body, request_headers: {})).to eq(failed)
    expect(app).to have_received(:call).once
    expect(body).not_to have_received(:read)
  end

  it 'honors a due or past HTTP-date without falling back to exponential delay' do
    now = Time.utc(2026, 1, 1)
    expect(handler.send(:retry_after, now.httpdate, now)).to eq(0)
    expect(handler.send(:retry_after, (now - 60).httpdate, now)).to eq(0)
    expect(handler.send(:retry_after, '0', now)).to eq(0)
  end

  it 'rejects fractional retry counts' do
    expect { option_class.new(max_retries: 1.5) }.to raise_error(ArgumentError)
  end

  it 'preserves the upload body when a Faraday adapter mutates its environment' do
    seen = []
    connection = Faraday.new do |builder|
      builder.use described_class, option_class.new(delay: 0)
      builder.adapter :test do |stub|
        stub.put('/upload') do |env|
          seen << [env.body, env.request_headers['Retry-Attempt']]
          seen.size == 1 ? [503, {}, 'retry response'] : [200, {}, 'ok']
        end
      end
    end

    expect(connection.put('/upload', 'original upload').body).to eq('ok')
    expect(seen).to eq([['original upload', nil], ['original upload', '1']])
  end
  [429, 503, 504].each do |status|
    it "retries the default status #{status} and caps the server delay" do
      failed = Faraday::Response.new(status: status, response_headers: { 'Retry-After' => '1000' }, body: '')
      allow(app).to receive(:call).and_return(failed, success)

      expect(handler.call(body: nil, request_headers: {})).to eq(success)
      expect(handler).to have_received(:sleep).with(180)
    end
  end

  it 'keeps streamed response details on retry exhaustion' do
    streams = [StringIO.new('first'), StringIO.new('last')]
    failures = streams.map { |stream| Faraday::Response.new(status: 503, response_headers: {}, body: stream) }
    allow(app).to receive(:call).and_return(*failures)
    limited = described_class.new(app, option_class.new(max_retries: 1, delay: 0))
    allow(limited).to receive(:sleep)

    expect { limited.call(body: nil, request_headers: {}) }.to raise_error(
      MicrosoftKiotaFaraday::Middleware::RetryExhaustedError
    ) do |error|
      expect(error.responses.map(&:body)).to eq(%w[first last])
      expect(streams).to all(be_closed)
    end
  end

  it 'does not retry requests using response streaming callbacks' do
    env = Faraday::Env.new
    env.request = Faraday::RequestOptions.new
    env.request.on_data = ->(_chunk, _bytes) {}
    allow(app).to receive(:call).with(env).and_return(success)

    expect(handler.call(env)).to eq(success)
    expect(app).to have_received(:call).once
  end
  it 'replays only the original remaining upload bytes on every retry' do
    body = StringIO.new('rawbytes')
    body.pos = 3
    uploads = []
    allow(app).to receive(:call) do |env|
      uploads << [env[:body].read, env[:request_headers]['Content-Length']]
      uploads.size < 3 ? Faraday::Response.new(status: 503, response_headers: {}, body: '') : success
    end

    expect(handler.call(body: body, request_headers: { 'Content-Length' => '5' })).to eq(success)
    expect(uploads).to eq([%w[bytes 5], %w[bytes 5], %w[bytes 5]])
  end

  it 'raises exhaustion before budgeting a hypothetical extra retry' do
    responses = 2.times.map { Faraday::Response.new(status: 503, response_headers: {}, body: 'busy') }
    allow(app).to receive(:call).and_return(*responses)
    limited = described_class.new(app, option_class.new(max_retries: 1, delay: 3, retries_time_limit: 3))
    allow(limited).to receive(:sleep)

    expect { limited.call(body: nil, request_headers: {}) }.to raise_error(
      MicrosoftKiotaFaraday::Middleware::RetryExhaustedError
    ) do |error|
      expect(error.responses).to eq(responses)
    end
    expect(app).to have_received(:call).twice
    expect(limited).to have_received(:sleep).once.with(3)
  end

  [Errno::ESPIPE, Errno::EPIPE, IOError].each do |error_class|
    it "leaves a stream with an unreadable position alone on #{error_class}" do
      body = double('request stream', read: 'data', seek: nil)
      allow(body).to receive(:pos).and_raise(error_class)
      failed = Faraday::Response.new(status: 503, response_headers: {}, body: 'busy')
      allow(app).to receive(:call).and_return(failed)

      expect(handler.call(body: body, request_headers: {})).to eq(failed)
      expect(app).to have_received(:call).once
      expect(body).not_to have_received(:seek)
      expect(handler).not_to have_received(:sleep)
    end
  end
end
