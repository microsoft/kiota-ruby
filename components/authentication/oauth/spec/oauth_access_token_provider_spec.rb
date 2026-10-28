# frozen_string_literal: true

require 'uri'
require 'microsoft_kiota_abstractions'
require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider do
  let(:context) do
    MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret', {})
  end
  let(:allowed_hosts) { ['api.example.com'] }
  let(:provider) { described_class.new(context, allowed_hosts, ['https://api.example.com/.default']) }
  let(:token) { instance_double(OAuth2::AccessToken, token: 'test_token', to_hash: {}) }

  before do
    allow(context).to receive(:get_token).and_return(token)
    allow(context).to receive(:initialize_scopes)
  end

  it 'returns a fiber yielding nil for a host outside the allowed hosts' do
    result = provider.get_authorization_token('https://other.example.com')

    expect(result).to be_a(Fiber)
    expect(result.resume).to be_nil
    expect(context).not_to have_received(:initialize_scopes)
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a fiber yielding nil for an unapproved loopback host' do
    result = provider.get_authorization_token('http://localhost:8080/v1.0')

    expect(result).to be_a(Fiber)
    expect(result.resume).to be_nil
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a fiber yielding nil for a missing or empty URI' do
    [nil, ' '].each do |uri|
      result = provider.get_authorization_token(uri)

      expect(result).to be_a(Fiber)
      expect(result.resume).to be_nil
    end
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a fiber yielding nil for a malformed or relative URI' do
    ['http://:8080/v1.0', '/relative/path', 'http://[::1'].each do |uri|
      result = provider.get_authorization_token(uri)

      expect(result).to be_a(Fiber)
      expect(result.resume).to be_nil
    end
    expect(context).not_to have_received(:get_token)
  end

  it 'returns a token for an allowed host' do
    expect(provider.get_authorization_token('https://api.example.com').resume).to eq('test_token')
    expect(context).to have_received(:get_token).once
  end

  it 'raises error for allowlisted external HTTP target' do
    expect do
      provider.get_authorization_token('http://api.example.com/v1.0')
    end.to raise_error(StandardError, 'Only https is supported')
  end

  it 'returns a fiber yielding nil for external HTTP target not in allowed hosts' do
    result = provider.get_authorization_token('http://other.example.com/v1.0')

    expect(result).to be_a(Fiber)
    expect(result.resume).to be_nil
    expect(context).not_to have_received(:get_token)
  end

  context 'with no allowed hosts configured' do
    let(:allowed_hosts) { [] }

    it 'returns a token for any HTTPS host' do
      expect(provider.get_authorization_token('https://other.example.com').resume).to eq('test_token')
    end

    it 'raises error for external HTTP target' do
      expect do
        provider.get_authorization_token('http://other.example.com/v1.0')
      end.to raise_error(StandardError, 'Only https is supported')
    end
  end

  it 'allows http on localhost and loopback addresses when allowed hosts is empty or includes loopback' do
    ['localhost', '127.0.0.1', '[::1]'].each do |host|
      url = "http://#{host}:8080/v1.0"

      provider_empty = described_class.new(context, [])
      fiber_empty = provider_empty.get_authorization_token(url)
      expect(fiber_empty).to be_a(Fiber)
      expect(fiber_empty.resume).to eq('test_token')

      [host, host.delete_prefix('[').delete_suffix(']')].uniq.each do |allowed_entry|
        provider_allowlisted = described_class.new(context, [allowed_entry])
        fiber_allowlisted = provider_allowlisted.get_authorization_token(url)
        expect(fiber_allowlisted).to be_a(Fiber)
        expect(fiber_allowlisted.resume).to eq('test_token')
      end
    end
  end

  it 'raises error for unsupported schemes even on localhost' do
    provider_empty = described_class.new(context, [])

    ['ftp://localhost:8080/v1.0', 'ws://localhost:8080/v1.0', '//localhost:8080/v1.0'].each do |url|
      expect do
        provider_empty.get_authorization_token(url)
      end.to raise_error(StandardError, 'Only https is supported')
    end
  end
end

RSpec.describe MicrosoftKiotaAuthenticationOAuth::OAuthAccessTokenProvider, 'scopes and caching' do
  let(:context) do
    MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret', {})
  end
  let(:allowed_hosts) { %w[one.example.com two.example.com] }
  let(:provider) { described_class.new(context, allowed_hosts) }
  let(:tokens) do
    [
      instance_double(OAuth2::AccessToken, token: 'one_token', to_hash: {}),
      instance_double(OAuth2::AccessToken, token: 'two_token', to_hash: {})
    ]
  end

  before do
    allow(context).to receive(:get_token).and_return(*tokens)
    allow(context).to receive(:initialize_scopes)
  end

  it 'derives the default scope for each request without mutating configured scopes' do
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')
    expect(provider.get_authorization_token('https://two.example.com').resume).to eq('two_token')

    expect(context).to have_received(:initialize_scopes).with(['https://one.example.com/.default'])
    expect(context).to have_received(:initialize_scopes).with(['https://two.example.com/.default'])
    expect(context).to have_received(:get_token).twice
    expect(provider.scopes).to eq([])
  end

  it 'reuses a cached token only for its effective scopes' do
    one_token = OAuth2::AccessToken.new(context.oauth_provider, 'one_token', expires_in: 3600)
    two_token = OAuth2::AccessToken.new(context.oauth_provider, 'two_token', expires_in: 3600)
    allow(context).to receive(:get_token).and_return(one_token, two_token)

    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')
    expect(provider.get_authorization_token('https://two.example.com').resume).to eq('two_token')
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('one_token')

    expect(context).to have_received(:get_token).twice
  end

  it 'returns an unexpired cached token without requesting a new one' do
    cached_token = OAuth2::AccessToken.new(context.oauth_provider, 'cached_token', expires_in: 3600)
    allow(context).to receive(:get_token).and_return(cached_token)

    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('cached_token')
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('cached_token')

    expect(context).to have_received(:get_token).once
  end

  it 'refreshes an expired token in the cache' do
    expired_token = OAuth2::AccessToken.new(
      context.oauth_provider, 'old_token', refresh_token: 'refresh_val', expires_in: -10
    )
    refreshed_token = OAuth2::AccessToken.new(
      context.oauth_provider, 'refreshed_token', expires_in: 3600
    )
    allow(context).to receive(:get_token).and_return(expired_token)
    allow_any_instance_of(OAuth2::AccessToken).to receive(:refresh!).and_return(refreshed_token)

    provider.get_authorization_token('https://one.example.com').resume
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('refreshed_token')

    expect(context).to have_received(:get_token).once
  end

  it 'requests a new token when an expired token has no refresh token' do
    expired_token = OAuth2::AccessToken.new(context.oauth_provider, 'old_token', expires_in: -10)
    new_token = OAuth2::AccessToken.new(context.oauth_provider, 'new_token', expires_in: 3600)
    allow(context).to receive(:get_token).and_return(expired_token, new_token)
    expect_any_instance_of(OAuth2::AccessToken).not_to receive(:refresh!)

    provider.get_authorization_token('https://one.example.com').resume
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('new_token')
    expect(provider.get_authorization_token('https://one.example.com').resume).to eq('new_token')

    expect(context).to have_received(:get_token).twice
  end

  it 'does not mutate explicitly configured scopes' do
    configured_scopes = ['https://resource.example.com/.default']
    explicit_provider = described_class.new(context, allowed_hosts, configured_scopes)

    expect(explicit_provider.scopes).to eq(configured_scopes)
    expect(explicit_provider.scopes).not_to equal(configured_scopes)
    explicit_provider.get_authorization_token('https://one.example.com').resume

    expect(explicit_provider.scopes).to eq(configured_scopes)
    expect(configured_scopes).to eq(['https://resource.example.com/.default'])
    expect(context).to have_received(:initialize_scopes).with(configured_scopes)
  end
end

RSpec.describe MicrosoftKiotaAuthenticationOAuth::OAuthAuthenticationProvider do
  let(:context) do
    MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new('tenant_id', 'client_id', 'client_secret', {})
  end
  let(:token) { instance_double(OAuth2::AccessToken, token: 'test_token', to_hash: {}) }

  before do
    allow(context).to receive(:get_token).and_return(token)
    allow(context).to receive(:initialize_scopes)
  end

  it 'leaves a request to a host outside the allowed hosts without an authorization header' do
    authentication_provider = described_class.new(
      context, ['api.example.com'], ['https://api.example.com/.default']
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'https://other.example.com'

    authentication_provider.authenticate_request(request).resume

    expect(request.headers.get_all).not_to have_key('Authorization')
    expect(context).not_to have_received(:get_token)
  end

  it 'authenticates http localhost request via OAuthAuthenticationProvider' do
    authentication_provider = described_class.new(
      context, ['localhost'], []
    )
    request = MicrosoftKiotaAbstractions::RequestInformation.new
    request.uri = 'http://localhost:8080/v1.0'

    authentication_provider.authenticate_request(request).resume
    expect(request.headers.get('Authorization').first).to eq('Bearer test_token')
  end
end
