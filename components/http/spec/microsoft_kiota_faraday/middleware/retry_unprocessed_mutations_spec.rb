# frozen_string_literal: true

RSpec.describe MicrosoftKiotaFaraday::Middleware::RetryHandler do
  let(:option_class) { MicrosoftKiotaFaraday::Middleware::RetryHandlerOption }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:requests) { [] }

  # Builds the default redirect-then-retry order with the given client-wide retry option.
  def client(retry_option)
    Faraday.new('https://example.com') do |builder|
      builder.use MicrosoftKiotaFaraday::Middleware::RedirectHandler
      builder.use described_class, retry_option
      builder.adapter :test, stubs
    end
  end

  # Answers requests to path with each status in turn, then 200, and records each request.
  def stub_statuses(path, statuses)
    remaining = statuses.dup
    %i[get post put patch delete].each do |verb|
      stubs.public_send(verb, path) do |env|
        requests << "#{env.method.to_s.upcase} #{env.url.path}"
        [remaining.shift || 200, {}, '']
      end
    end
  end

  def send_request(retry_option, method, request_option: nil)
    client(retry_option).run_request(method, '/send', method == :get ? nil : '{"message":"hello"}', {}) do |request|
      request.options.context = { request_option.get_key => request_option } if request_option
    end
  end

  def enabled_option
    option_class.new(delay: 0, retry_unprocessed_mutations_only: true)
  end

  it 'defaults retry_unprocessed_mutations_only to false' do
    expect(option_class.new.retry_unprocessed_mutations_only).to be false
    expect(enabled_option.retry_unprocessed_mutations_only).to be true
  end

  %i[post patch].each do |method|
    it "retries #{method.upcase} on 504 by default" do
      stub_statuses('/send', [504])

      response = send_request(option_class.new(delay: 0), method)

      expect(response.status).to eq(200)
      expect(requests.size).to eq(2)
    end

    it "does not retry #{method.upcase} on 504 when enabled" do
      stub_statuses('/send', [504])

      response = send_request(enabled_option, method)

      expect(response.status).to eq(504)
      expect(requests.size).to eq(1)
    end

    [429, 503].each do |status|
      it "retries #{method.upcase} on #{status} when enabled" do
        stub_statuses('/send', [status])

        response = send_request(enabled_option, method)

        expect(response.status).to eq(200)
        expect(requests.size).to eq(2)
      end
    end
  end

  it 'does not retry a POST on a status that a custom should_retry accepts when enabled' do
    stub_statuses('/send', [500])
    option = option_class.new(delay: 0, should_retry: ->(_delay, _retries, _response) { true },
                              retry_unprocessed_mutations_only: true)

    response = send_request(option, :post)

    expect(response.status).to eq(500)
    expect(requests.size).to eq(1)
  end

  it 'matches the method ignoring case' do
    handler = described_class.new(nil, enabled_option)
    response = Faraday::Response.new(status: 504)

    expect(handler.send(:retryable_for_method?, 'post', response, enabled_option)).to be false
    expect(handler.send(:retryable_for_method?, :patch, response, enabled_option)).to be false
  end

  %i[get put delete].each do |method|
    it "retries #{method.upcase} on 504 when enabled" do
      stub_statuses('/send', [504])

      response = send_request(enabled_option, method)

      expect(response.status).to eq(200)
      expect(requests.size).to eq(2)
    end
  end

  it 'stops retrying a POST when a later response leaves the outcome unknown' do
    stub_statuses('/send', [503, 504])

    response = send_request(enabled_option, :post)

    expect(response.status).to eq(504)
    expect(requests.size).to eq(2)
  end

  it 'honours the option from the request context' do
    stub_statuses('/send', [504])

    response = send_request(option_class.new(delay: 0), :post, request_option: enabled_option)

    expect(response.status).to eq(504)
    expect(requests.size).to eq(1)
  end

  it 'retries a POST that a redirect changed to GET when enabled' do
    stubs.post('/send') do |env|
      requests << "POST #{env.url.path}"
      [303, { 'Location' => '/redirected' }, '']
    end
    stub_statuses('/redirected', [504])

    response = send_request(enabled_option, :post)

    expect(response.status).to eq(200)
    expect(requests).to eq(['POST /send', 'GET /redirected', 'GET /redirected'])
  end

  it 'does not retry a POST that a redirect kept as POST when enabled from the request context' do
    stubs.post('/send') do |env|
      requests << "POST #{env.url.path}"
      [307, { 'Location' => '/redirected' }, '']
    end
    stub_statuses('/redirected', [504])

    response = send_request(option_class.new(delay: 0), :post, request_option: enabled_option)

    expect(response.status).to eq(504)
    expect(requests).to eq(['POST /send', 'POST /redirected'])
  end
end
