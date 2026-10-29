# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaSerializationJson::JsonParseNodeFactory do
  subject(:factory) { described_class.new }

  let(:json_content_type) { 'application/json' }
  let(:sample_json_string) { '{"name":"Tesla","city":"New York"}' }

  it 'gets a root parse node' do
    expect(factory.get_parse_node(json_content_type, sample_json_string))
      .to be_a(MicrosoftKiotaSerializationJson::JsonParseNode)
  end

  it 'raises without a content type' do
    [nil, ''].each do |content_type|
      expect { factory.get_parse_node(content_type, sample_json_string) }
        .to raise_error(ArgumentError, 'content type cannot be undefined or empty')
    end
  end

  it 'raises on an unsupported content type' do
    expect { factory.get_parse_node('application/xml', sample_json_string) }
      .to raise_error(ArgumentError, "expected a #{json_content_type} content type")
  end

  it 'raises without content' do
    expect { factory.get_parse_node(json_content_type, nil) }
      .to raise_error(ArgumentError, 'content cannot be undefined or empty')
  end

  it 'gets the valid content type' do
    expect(factory.get_valid_content_type).to eq(json_content_type)
  end

  it 'matches the content type case-insensitively' do
    expect(factory.get_parse_node(json_content_type.upcase, sample_json_string).get_child_node('city').get_string_value)
      .to eq('New York')
  end
end
