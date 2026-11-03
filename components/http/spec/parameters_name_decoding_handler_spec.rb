# frozen_string_literal: true

require 'faraday'

RSpec.describe MicrosoftKiotaFaraday do
  it 'decodes encoded query parameters' do
    values = {}
    values['?%24select=diplayName&api%2Dversion=2'] = '?$select=diplayName&api-version=2'
    values['?%24select=diplayName&api%7Eversion=2'] = '?$select=diplayName&api~version=2'
    values['?%24select=diplayName&api%2Eversion=2'] = '?$select=diplayName&api.version=2'
    values['/api-version/?%24select=diplayName&api%2Eversion=2'] = '/api-version/?$select=diplayName&api.version=2'
    values[''] = ''

    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    values.each do |key, value|
      env = {
        url: URI.parse("https://graph.microsoft.com/v1.0/users#{key}")
      }
      handler.call(env)
      expect(env[:url].to_s).to eq("https://graph.microsoft.com/v1.0/users#{value}")
    end
  end

  it "doesn't decode when disabled on request" do
    values = {}
    values['?%24select=diplayName&api%2Dversion=2'] = '?%24select=diplayName&api%2Dversion=2'
    values['?%24select=diplayName&api%7Eversion=2'] = '?%24select=diplayName&api%7Eversion=2'
    values['?%24select=diplayName&api%2Eversion=2'] = '?%24select=diplayName&api%2Eversion=2'
    values['/api-version/?%24select=diplayName&api%2Eversion=2'] =
      '/api-version/?%24select=diplayName&api%2Eversion=2'
    values[''] = ''

    option = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingOption.new(false)
    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    values.each do |key, value|
      env = {
        url: URI.parse("https://graph.microsoft.com/v1.0/users#{key}"),
        request: {
          context: {
            option.get_key => option
          }
        }
      }
      handler.call(env)
      expect(env[:url].to_s).to eq("https://graph.microsoft.com/v1.0/users#{value}")
    end
  end

  it 'preserves encoded characters in path segments and only decodes parameter names' do
    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    env = {
      url: URI.parse('https://graph.microsoft.com/v1.0/%24users/%2Ditems?%24select=displayName&api%2Dversion=2')
    }
    handler.call(env)
    expect(env[:url].to_s).to eq('https://graph.microsoft.com/v1.0/%24users/%2Ditems?$select=displayName&api-version=2')
  end

  it 'preserves encoded characters in query parameter values' do
    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    env = {
      url: URI.parse('https://graph.microsoft.com/v1.0/users?%24filter=name%20eq%20%27foo%24bar%27&api%2Dversion=2')
    }
    handler.call(env)
    expect(env[:url].to_s).to eq('https://graph.microsoft.com/v1.0/users?$filter=name%20eq%20%27foo%24bar%27&api-version=2')
  end

  it 'preserves query parameter values containing equals signs and repeated parameters' do
    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    env = {
      url: URI.parse('https://graph.microsoft.com/v1.0/users?q=YWJjZA==&%24top=10&%24top=20')
    }
    handler.call(env)
    expect(env[:url].to_s).to eq('https://graph.microsoft.com/v1.0/users?q=YWJjZA==&$top=10&$top=20')
  end

  it 'handles URLs without a query string or without encoded characters' do
    handler = MicrosoftKiotaFaraday::Middleware::ParametersNameDecodingHandler.new
    env1 = { url: URI.parse('https://graph.microsoft.com/v1.0/users') }
    handler.call(env1)
    expect(env1[:url].to_s).to eq('https://graph.microsoft.com/v1.0/users')

    env2 = { url: URI.parse('https://graph.microsoft.com/v1.0/users?name=test') }
    handler.call(env2)
    expect(env2[:url].to_s).to eq('https://graph.microsoft.com/v1.0/users?name=test')
  end
end
