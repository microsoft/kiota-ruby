# frozen_string_literal: true

require 'time'

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  it 'uses an HTTP-date Retry-After value as the delay' do
    retry_at = Time.now.utc + 60
    env = { response_headers: { 'Retry-After' => retry_at.httpdate } }

    delay = described_class.new(nil).send(:calculate_retry_after, env)

    expect(delay).to be_between(58, 60).inclusive
  end

  it 'is included in the default middleware pipeline' do
    expect(MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware).to include(described_class)
  end
end
