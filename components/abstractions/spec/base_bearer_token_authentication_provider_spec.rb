# frozen_string_literal: true

require 'uri'
require 'microsoft_kiota_abstractions'
require_relative 'access_token_provider_mock'

RSpec.describe MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider do
  it 'creates a token authentication provider with existing authorization header' do
    access_token_provider = AccessTokenProviderMock.new
    token_provider = MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider.new(access_token_provider)
    expect(token_provider).not_to be nil
    request_obj = MicrosoftKiotaAbstractions::RequestInformation.new
    request_obj.headers.add(
      MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider::AUTHORIZATION_HEADER_KEY, 'SAMPLE'
    )
    token_provider.authenticate_request(request_obj).resume
    expect(request_obj.headers.get(MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider::AUTHORIZATION_HEADER_KEY).at(0)).to eq 'SAMPLE'
  end

  it 'creates a token authentication provider with mock access token' do
    access_token_provider = AccessTokenProviderMock.new
    token_provider = MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider.new(access_token_provider)
    expect(token_provider).not_to be nil
    request_obj = MicrosoftKiotaAbstractions::RequestInformation.new
    request_obj.uri = 'http://sample.com'
    token_provider.authenticate_request(request_obj).resume
    expect(request_obj.headers.get(MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider::AUTHORIZATION_HEADER_KEY).at(0)).to eq "Bearer #{AccessTokenProviderMock::DUMMY_TOKEN}"
  end

  it 'safely handles nil token or nil fiber from access token provider' do
    nil_provider = double('AccessTokenProvider', get_authorization_token: nil)
    token_provider = MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider.new(nil_provider)
    request_obj = MicrosoftKiotaAbstractions::RequestInformation.new
    request_obj.uri = 'https://example.com'
    header_key = MicrosoftKiotaAbstractions::BaseBearerTokenAuthenticationProvider::AUTHORIZATION_HEADER_KEY
    expect { token_provider.authenticate_request(request_obj).resume }.not_to raise_error
    expect(request_obj.headers.get_all.key?(header_key)).to be(false)
  end
end
