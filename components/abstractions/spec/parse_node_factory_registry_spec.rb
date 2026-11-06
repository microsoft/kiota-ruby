# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require_relative 'parse_node_factory_mock'

RSpec.describe MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry do
  let(:mock_factory) { ParseNodeFactoryMock.new }
  let(:serialized_value) { '[1]' }

  before do
    described_class.default_instance.content_type_associated_factories['application/json'] = mock_factory
  end

  it 'gets the parse node for standard, parameterized, and vendor-specific content types' do
    values = [
      'application/json',
      'application/json;odata.metadata=minimal;odata.streaming=true;IEEE754Compatible=false;charset=utf-8',
      'application/json ; charset=utf-8',
      'application/vnd.github.mercy-preview+json',
      'application/vnd.github.mercy-preview+json;odata.metadata=minimal;odata.streaming=true;IEEE754Compatible=false;charset=utf-8',
      "application/#{Array.new(10, 'vendor').join('.')}+json"
    ]

    values.each do |value|
      expect(described_class.default_instance.get_parse_node(value, serialized_value)).not_to be_nil
    end
  end

  it 'raises when content type is nil, empty, or whitespace only' do
    [nil, '', '   '].each do |bad_type|
      expect do
        described_class.default_instance.get_parse_node(bad_type, serialized_value)
      end.to raise_error(StandardError, 'content type cannot be undefined or empty')
    end
  end

  it 'raises when content is nil or empty' do
    [nil, ''].each do |bad_content|
      expect do
        described_class.default_instance.get_parse_node('application/json', bad_content)
      end.to raise_error(StandardError, 'content cannot be undefined or empty')
    end
  end

  it 'works on a freshly created instance without pre-accessing content_type_associated_factories' do
    registry = described_class.new
    expect do
      registry.get_parse_node('application/xml', serialized_value)
    end.to raise_error(StandardError, /does not have a factory/)

    registry.content_type_associated_factories['application/xml'] = mock_factory
    expect(registry.get_parse_node('application/xml', serialized_value)).not_to be_nil
  end

  it 'raises when no factory is registered for the content type' do
    expect do
      described_class.default_instance.get_parse_node('application/unknown-type', serialized_value)
    end.to raise_error(StandardError, /does not have a factory/)
  end
end
