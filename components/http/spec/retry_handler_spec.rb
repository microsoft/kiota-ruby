# frozen_string_literal: true

require 'time'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandlerOption do
  it 'accepts values within bounds' do
    option = described_class.new(max_retries: 5, delay: 10)

    expect(option.max_retries).to eq(5)
    expect(option.delay).to eq(10)
  end

  it 'raises for a max_retries above the allowed bound' do
    expect { described_class.new(max_retries: described_class::MAX_RETRIES + 1) }.to raise_error(ArgumentError)
  end

  it 'raises for a negative max_retries' do
    expect { described_class.new(max_retries: -1) }.to raise_error(ArgumentError)
  end

  it 'raises for a delay above the allowed bound' do
    expect { described_class.new(delay: described_class::MAX_DELAY + 1) }.to raise_error(ArgumentError)
  end

  it 'raises for a negative delay' do
    expect { described_class.new(delay: -1) }.to raise_error(ArgumentError)
  end
end

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  it 'uses an HTTP-date Retry-After value as the delay' do
    now = Time.utc(2026, 1, 1)
    retry_at = now + 60

    delay = described_class.new(nil).send(:retry_after, retry_at.httpdate, now)

    expect(delay).to eq(60)
  end

  it 'falls back to nil for a malformed Retry-After value' do
    delay = described_class.new(nil).send(:retry_after, 'not-a-valid-header')

    expect(delay).to be_nil
  end

  it 'retries a retryable response and records the attempt' do
    app = double
    unavailable = Struct.new(:status, :headers).new(503, { 'Retry-After' => '1' })
    success = Struct.new(:status, :headers).new(200, {})
    allow(app).to receive(:call).and_return(unavailable, success)
    handler = described_class.new(app)
    allow(handler).to receive(:sleep)
    request = { body: nil, request_headers: {} }

    expect(handler.call(request)).to eq(success)
    expect(app).to have_received(:call).twice
    expect(request[:request_headers]['Retry-Attempt']).to eq('1')
  end

  it 'backs off exponentially across repeated failures without a Retry-After header' do
    app = double
    unavailable = Struct.new(:status, :headers).new(503, {})
    success = Struct.new(:status, :headers).new(200, {})
    allow(app).to receive(:call).and_return(unavailable, unavailable, unavailable, success)
    handler = described_class.new(app)
    sleeps = []
    allow(handler).to receive(:sleep) { |seconds| sleeps << seconds }
    option = MicrosoftKiotaFaraday::Middleware::RetryHandlerOption.new(max_retries: 5, delay: 2)
    request = { body: nil, request_headers: {}, request: { context: { option.get_key => option } } }

    expect(handler.call(request)).to eq(success)
    expect(sleeps).to eq([2, 4, 8])
  end

  it 'stops retrying once max_retries is exhausted' do
    app = double
    unavailable = Struct.new(:status, :headers).new(503, {})
    allow(app).to receive(:call).and_return(unavailable, unavailable)
    handler = described_class.new(app)
    allow(handler).to receive(:sleep)
    option = MicrosoftKiotaFaraday::Middleware::RetryHandlerOption.new(max_retries: 1, delay: 1)
    request = { body: nil, request_headers: {}, request: { context: { option.get_key => option } } }

    expect(handler.call(request)).to eq(unavailable)
    expect(app).to have_received(:call).twice
  end

  it 'does not retry status codes outside the retryable set' do
    app = double
    not_found = Struct.new(:status, :headers).new(404, {})
    allow(app).to receive(:call).and_return(not_found)
    handler = described_class.new(app)
    allow(handler).to receive(:sleep)
    request = { body: nil, request_headers: {} }

    expect(handler.call(request)).to eq(not_found)
    expect(app).to have_received(:call).once
    expect(handler).not_to have_received(:sleep)
  end

  it 'is included in the default middleware pipeline' do
    expect(MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware).to include(described_class)
  end
end
