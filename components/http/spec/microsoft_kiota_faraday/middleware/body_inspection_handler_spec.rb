# frozen_string_literal: true

require 'stringio'

RSpec.describe 'Body inspection' do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:client) do
    Faraday.new('https://example.com') do |builder|
      MicrosoftKiotaFaraday::KiotaClientFactory.get_default_middleware.each { |handler| builder.use handler }
      builder.adapter :test, stubs
    end
  end

  def post_body(body, option, follow_redirects: true)
    context = { option.get_key => option }
    unless follow_redirects
      redirect = MicrosoftKiotaFaraday::Middleware::RedirectHandlerOption.new(max_redirects: 0)
      context[redirect.get_key] = redirect
    end

    client.post('/items', body) do |request|
      request.options.context = context
    end
  end

  it 'copies the remaining request stream without changing what the transport reads' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(inspect_request_body: true)
    body = StringIO.new('prefixpayload')
    body.pos = 6
    stubs.post('/items') do |env|
      expect(env.body).to equal(body)
      expect(env.body.pos).to eq(6)
      expect(env.body.read).to eq('payload')
      [200, {}, 'reply']
    end

    post_body(body, option, follow_redirects: false)

    expect(option.request_body.read).to eq('payload')
    expect(option.response_body).to be_nil
  end

  it 'copies an error response without replacing the response body' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(inspect_response_body: true)
    stubs.post('/items') { [400, {}, +'error details'] }

    response = post_body('request', option)

    expect(response.status).to eq(400)
    expect(option.request_body).to be_nil
    expect(option.response_body.read).to eq('error details')
    option.response_body.rewind
    option.response_body.write('other')
    expect(response.body).to eq('error details')
  end

  it 'copies the original request and the final response across a redirect' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(
      inspect_request_body: true, inspect_response_body: true
    )
    stubs.post('/items') { [303, { 'Location' => '/result' }, 'intermediate'] }
    stubs.get('/result') do |env|
      expect(env.body).to be_nil
      [200, {}, 'final']
    end

    expect(post_body('payload', option).body).to eq('final')
    expect(option.request_body.read).to eq('payload')
    expect(option.response_body.read).to eq('final')
  end

  it 'leaves a non-seekable request stream for the transport to consume' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(inspect_request_body: true)
    stubs.post('/items') do |env|
      expect(env.body.read).to eq('payload')
      [200, {}, 'reply']
    end

    IO.pipe do |reader, writer|
      writer.write('payload')
      writer.close
      post_body(reader, option, follow_redirects: false)
    end

    expect(option.request_body).to be_nil
  end

  it 'preserves the request body when a position probe raises EPIPE' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(inspect_request_body: true)
    body = StringIO.new('payload')
    allow(body).to receive(:pos).and_raise(Errno::EPIPE)
    stubs.post('/items') do |env|
      expect(env.body).to equal(body)
      expect(env.body.read).to eq('payload')
      [200, {}, 'reply']
    end

    post_body(body, option, follow_redirects: false)

    expect(option.request_body).to be_nil
  end

  it 'does not copy either body by default' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new
    stubs.post('/items') { [200, {}, 'reply'] }

    post_body('request', option)

    expect(option.request_body).to be_nil
    expect(option.response_body).to be_nil
  end
end
