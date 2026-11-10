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

  def post_body(body, option)
    client.post('/items', body) do |request|
      request.options.context = { option.get_key => option }
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

    post_body(body, option)

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

  it 'leaves a non-seekable request stream for the transport to consume' do
    option = MicrosoftKiotaFaraday::Middleware::BodyInspectionOption.new(inspect_request_body: true)
    stubs.post('/items') do |env|
      expect(env.body.read).to eq('payload')
      [200, {}, 'reply']
    end

    IO.pipe do |reader, writer|
      writer.write('payload')
      writer.close
      post_body(reader, option)
    end

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
