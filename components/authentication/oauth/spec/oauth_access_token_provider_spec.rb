# frozen_string_literal: true

require 'uri'
require 'microsoft_kiota_abstractions'
require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider do
  it 'returns a fiber resolving to nil when uri is nil or not in allowed hosts' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, ['graph.microsoft.com'])

    fiber_nil = provider.get_authorization_token(nil)
    expect(fiber_nil).to be_a(Fiber)
    expect(fiber_nil.resume).to be_nil

    fiber_untrusted = provider.get_authorization_token('https://untrusted.com/v1.0')
    expect(fiber_untrusted).to be_a(Fiber)
    expect(fiber_untrusted.resume).to be_nil

    fiber_http_untrusted = provider.get_authorization_token('http://untrusted.com/v1.0')
    expect(fiber_http_untrusted).to be_a(Fiber)
    expect(fiber_http_untrusted.resume).to be_nil

    fiber_loopback_unapproved = provider.get_authorization_token('http://localhost:8080/v1.0')
    expect(fiber_loopback_unapproved).to be_a(Fiber)
    expect(fiber_loopback_unapproved.resume).to be_nil
  end

  it 'raises error for allowlisted external HTTP target' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, ['graph.microsoft.com'])

    expect do
      provider.get_authorization_token('http://graph.microsoft.com/v1.0')
    end.to raise_error(StandardError, 'Only https is supported')
  end

  it 'allows http on localhost and loopback addresses when allowed hosts is empty or includes loopback' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    allow(context).to receive(:get_token).and_return(double('token', to_hash: {}, token: 'test_token'))

    ['localhost', '127.0.0.1', '[::1]'].each do |host|
      url = "http://#{host}:8080/v1.0"

      provider_empty = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [])
      fiber_empty = provider_empty.get_authorization_token(url)
      expect(fiber_empty).to be_a(Fiber)
      expect(fiber_empty.resume).to eq('test_token')

      [host, host.delete_prefix('[').delete_suffix(']')].uniq.each do |allowed_entry|
        provider_allowlisted = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(
          context, [allowed_entry]
        )
        fiber_allowlisted = provider_allowlisted.get_authorization_token(url)
        expect(fiber_allowlisted).to be_a(Fiber)
        expect(fiber_allowlisted.resume).to eq('test_token')
      end
    end
  end

  it 'raises error for unsupported schemes even on localhost' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    provider = MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider.new(context, [])

    ['ftp://localhost:8080/v1.0', 'ws://localhost:8080/v1.0', '//localhost:8080/v1.0'].each do |url|
      expect do
        provider.get_authorization_token(url)
      end.to raise_error(StandardError, 'Only https is supported')
    end
  end

  it 'leaves request unauthenticated when host is not allowed via OAuthAuthenticationProvider' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    auth_provider = MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider.new(
      context, ['graph.microsoft.com'], []
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'https://untrusted.com/v1.0'

    expect { auth_provider.authenticate_request(request).resume }.not_to raise_error
    expect(request.headers.get_all.key?('Authorization')).to be(false)
  end

  it 'authenticates http localhost request via OAuthAuthenticationProvider' do
    context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
      'tenant_id', 'client_id', 'client_secret', {}
    )
    allow(context).to receive(:get_token).and_return(double('token', to_hash: {}, token: 'test_token'))

    auth_provider = MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider.new(
      context, ['localhost'], []
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'http://localhost:8080/v1.0'

    auth_provider.authenticate_request(request).resume
    expect(request.headers.get('Authorization').first).to eq('Bearer test_token')
  end
end
