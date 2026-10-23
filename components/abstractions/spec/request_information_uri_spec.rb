# frozen_string_literal: true

require 'date'
require 'microsoft_kiota_abstractions'

# stands in for UUIDTools::UUID, which this gem does not depend on
GuidLike = Struct.new(:value) do
  def to_s = value
end

RSpec.describe MicrosoftKiotaAbstractions::RequestInformation do
  def uri_for(template, path_parameters = {}, query_parameters = {})
    described_class.new.tap do |info|
      info.url_template = "{+baseurl}#{template}"
      info.path_parameters = { 'baseurl' => 'https://example.com' }.merge(path_parameters)
      query_parameters.each { |k, v| info.query_parameters[k] = v }
    end.uri.to_s
  end

  it 'expands a guid path parameter' do
    id = GuidLike.new('2b6d5b1a-2b6d-4b1a-8b6d-5b1a2b6d5b1a')
    expect(uri_for('/things/{id}', 'id' => id)).to eq('https://example.com/things/2b6d5b1a-2b6d-4b1a-8b6d-5b1a2b6d5b1a')
  end

  it 'expands date, time and date time query parameters as ISO 8601' do
    uri = uri_for('/things{?on,at,since}', {},
                  'on' => Date.new(2026, 1, 2), 'at' => Time.utc(2026, 1, 2, 3, 4, 5),
                  'since' => DateTime.new(2026, 1, 2, 3, 4, 5))
    expect(uri).to eq('https://example.com/things?on=2026-01-02&at=2026-01-02T03%3A04%3A05Z&since=2026-01-02T03%3A04%3A05%2B00%3A00')
  end

  it 'expands date times inside a list and a map' do
    at = DateTime.new(2026, 1, 2, 3, 4, 5)
    expect(uri_for('/things{?at*,window*}', {}, 'at' => [at], 'window' => { 'from' => at }))
      .to eq('https://example.com/things?at=2026-01-02T03%3A04%3A05%2B00%3A00&from=2026-01-02T03%3A04%3A05%2B00%3A00')
  end

  it 'expands a duration query parameter' do
    expect(uri_for('/things{?every}', {}, 'every' => MicrosoftKiotaAbstractions::ISODuration.new('PT1H')))
      .to eq('https://example.com/things?every=PT1H')
  end

  it 'expands symbols, alone and in a list' do
    expect(uri_for('/things{?kind,kinds}', {}, 'kind' => :read, 'kinds' => %i[read write]))
      .to eq('https://example.com/things?kind=read&kinds=read,write')
  end
end

RSpec.describe MicrosoftKiotaAbstractions::AllowedHostsValidator do
  it 'rejects an allowed host that carries a scheme' do
    expect { described_class.new(['https://example.com']) }.to raise_error(ArgumentError, /host/)
    expect { described_class.new([]).allowed_hosts = ['http://example.com'] }.to raise_error(ArgumentError, /host/)
  end

  it 'keeps the previous hosts when an update is rejected' do
    validator = described_class.new(['example.com'])
    expect { validator.allowed_hosts = ['other.com', 'https://bad.com'] }.to raise_error(ArgumentError)
    expect(validator.url_host_valid?('https://example.com')).to be(true)
    expect(validator.url_host_valid?('https://other.com')).to be(false)
  end

  it 'does not fall back to allowing every host when an update is rejected' do
    validator = described_class.new(['example.com'])
    expect { validator.allowed_hosts = ['https://bad.com'] }.to raise_error(ArgumentError)
    expect(validator.url_host_valid?('https://anything.com')).to be(false)
  end

  it 'validates host with https scheme and allows http for localhost' do
    validator = described_class.new(['example.com', 'localhost'])
    expect(validator.url_host_valid?('http://example.com')).to be(false)
    expect(validator.url_host_valid?('http://localhost:8080')).to be(true)
    expect(validator.url_host_valid?('https://example.com')).to be(true)
    expect(validator.url_host_valid?('https://other.com')).to be(false)
    expect(validator.url_host_valid?('http://other.com')).to be(false)
  end

  it 'validates IPv6 loopback hosts with both bracketed and unbracketed allowlist entries' do
    bracketed_validator = described_class.new(['[::1]'])
    expect(bracketed_validator.url_host_valid?('https://[::1]:8080/v1.0')).to be(true)
    expect(bracketed_validator.url_host_valid?('http://[::1]:8080/v1.0')).to be(true)
    expect(bracketed_validator.url_host_valid?('http://example.com')).to be(false)
    expect(bracketed_validator.url_host_valid?('https://example.com')).to be(false)

    unbracketed_validator = described_class.new(['::1'])
    expect(unbracketed_validator.url_host_valid?('https://[::1]:8080/v1.0')).to be(true)
    expect(unbracketed_validator.url_host_valid?('http://[::1]:8080/v1.0')).to be(true)
    expect(unbracketed_validator.url_host_valid?('http://example.com')).to be(false)
    expect(unbracketed_validator.url_host_valid?('https://example.com')).to be(false)
  end
end
