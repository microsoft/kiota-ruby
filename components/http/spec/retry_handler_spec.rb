# frozen_string_literal: true

require 'time'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  it 'uses an HTTP-date Retry-After value as the delay' do
    now = Time.utc(2026, 1, 1)
    retry_at = now + 60

    delay = described_class.new(nil).send(:retry_after, retry_at.httpdate, now)

    expect(delay).to eq(60)
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

  it 'is included in the default middleware pipeline' do
    expect(MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware).to include(described_class)
  end
end
