# frozen_string_literal: true

require 'stringio'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  let(:option_class) { MicrosoftKiotaFaraday::Middleware::RetryHandlerOption }
  let(:app) { double('app') }
  let(:handler) { described_class.new(app, option_class.new(delay: 0)) }
  let(:success) { Faraday::Response.new(status: 200, body: 'ok') }

  before { allow(handler).to receive(:sleep) }

  it 'drains multiple bounded chunks and closes the stream before retrying' do
    stream = StringIO.new('x' * ((16 * 1024 * 2) + 7))
    lengths = []
    sizes = []
    allow(stream).to receive(:read).and_wrap_original do |read, length = nil|
      lengths << length
      chunk = read.call(length)
      sizes << chunk&.bytesize
      chunk
    end
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
    expect(lengths).to eq([16 * 1024] * 4)
    expect(sizes).to eq([16 * 1024, 16 * 1024, 7, nil])
    expect(failed.body).to equal(stream)
  end

  [nil, ''].each do |eof|
    it "stops draining at #{eof.inspect} EOF and closes before retrying" do
      stream = double('empty response stream', close: nil)
      expect(stream).to receive(:read).with(16 * 1024).once.and_return(eof)
      failed = Faraday::Response.new(status: 503, response_headers: {}, body: stream)
      allow(app).to receive(:call).and_return(failed, success)

      expect(handler.call(body: nil, request_headers: {})).to eq(success)
      expect(stream).to have_received(:close).once
    end
  end

  it 'closes and propagates a read failure after successfully discarding a chunk' do
    stream = double('failing response stream', close: nil)
    reads = 0
    allow(stream).to receive(:read).with(16 * 1024) do
      reads += 1
      raise IOError, 'interrupted drain' if reads == 2

      'x' * (16 * 1024)
    end
    failed = Faraday::Response.new(status: 503, response_headers: {}, body: stream)
    allow(app).to receive(:call).and_return(failed)

    expect { handler.call(body: nil, request_headers: {}) }.to raise_error(IOError, 'interrupted drain')
    expect(reads).to eq(2)
    expect(stream).to have_received(:close).once
    expect(app).to have_received(:call).once
    expect(handler).not_to have_received(:sleep)
  end
end
