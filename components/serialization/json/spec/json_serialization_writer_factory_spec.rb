# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaSerializationJson::JsonSerializationWriterFactory do
  subject(:factory) { described_class.new }

  let(:json_content_type) { 'application/json' }

  it 'gets a serialization writer' do
    expect(factory.get_serialization_writer(json_content_type))
      .to be_a(MicrosoftKiotaSerializationJson::JsonSerializationWriter)
  end

  it 'raises without a content type' do
    [nil, ''].each do |content_type|
      expect { factory.get_serialization_writer(content_type) }
        .to raise_error(ArgumentError, 'content type cannot be undefined or empty')
    end
  end

  it 'raises on an unsupported content type' do
    expect { factory.get_serialization_writer('application/xml') }
      .to raise_error(ArgumentError, "expected a #{json_content_type} content type")
  end

  it 'gets the valid content type' do
    expect(factory.get_valid_content_type).to eq(json_content_type)
  end

  it 'matches the content type case-insensitively' do
    expect(factory.get_serialization_writer(json_content_type.upcase))
      .to be_a(MicrosoftKiotaSerializationJson::JsonSerializationWriter)
  end
end
