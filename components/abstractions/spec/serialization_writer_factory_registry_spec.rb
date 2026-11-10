# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require_relative 'serialization_writer_factory_mock'

RSpec.describe MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry do
  let(:mock_factory) { SerializationWriterFactoryMock.new }

  before do
    @previous_factory = described_class.default_instance.content_type_associated_factories['application/json']
    described_class.default_instance.content_type_associated_factories['application/json'] = mock_factory
  end

  after do
    if @previous_factory
      described_class.default_instance.content_type_associated_factories['application/json'] = @previous_factory
    else
      described_class.default_instance.content_type_associated_factories.delete('application/json')
    end
  end

  it 'gets the serialization writer for standard, parameterized, and vendor-specific content types' do
    values = [
      'application/json',
      'application/json;odata.metadata=minimal;odata.streaming=true;IEEE754Compatible=false;charset=utf-8',
      'application/json ; charset=utf-8',
      'application/vnd.github.mercy-preview+json',
      'application/vnd.github.mercy-preview+json;odata.metadata=minimal;odata.streaming=true;IEEE754Compatible=false;charset=utf-8',
      "application/#{Array.new(10, 'vendor').join('.')}+json",
      "application/#{Array.new(1000, 'vendor').join('.')}+json"
    ]

    values.each do |value|
      expect(described_class.default_instance.get_serialization_writer(value)).not_to be_nil
    end
  end

  it 'raises when content type is nil, empty, or whitespace only' do
    [nil, '', '   '].each do |bad_type|
      expect do
        described_class.default_instance.get_serialization_writer(bad_type)
      end.to raise_error(ArgumentError, 'content type cannot be undefined or empty')
    end
  end

  it 'works on a freshly created instance without pre-accessing content_type_associated_factories' do
    registry = described_class.new
    expect do
      registry.get_serialization_writer('application/xml')
    end.to raise_error(StandardError, /does not have a factory/)

    registry.content_type_associated_factories['application/xml'] = mock_factory
    expect(registry.get_serialization_writer('application/xml')).not_to be_nil
  end

  it 'raises when no factory is registered for the content type' do
    expect do
      described_class.default_instance.get_serialization_writer('application/unknown-type')
    end.to raise_error(StandardError, /does not have a factory/)
  end
end
