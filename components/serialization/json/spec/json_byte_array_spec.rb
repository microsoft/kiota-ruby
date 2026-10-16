# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

RSpec.describe 'byte array values' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }
  let(:bytes) { "\x00\xFFHello".b }

  it 'writes a byte array as base64' do
    writer.write_byte_array_value('data', bytes)
    expect(writer.get_serialized_content).to eq('{"data":"AP9IZWxsbw=="}')
  end

  it 'writes a byte array as the root value without a key' do
    writer.write_byte_array_value(nil, bytes)
    expect(writer.get_serialized_content).to eq('"AP9IZWxsbw=="')
  end

  it 'leaves an unset byte array off the wire' do
    writer.write_byte_array_value('data', nil)
    expect(writer.writer).to eq({})
  end

  it 'raises when both the key and the byte array are missing' do
    expect { writer.write_byte_array_value(nil, nil) }.to raise_error(StandardError, /no key or value/)
  end

  it 'reads a base64 string as a byte array' do
    value = MicrosoftKiotaSerializationJson::JsonParseNode.new('AP9IZWxsbw==').get_byte_array_value
    expect(value).to eq(bytes)
    expect(value.encoding).to eq(Encoding::BINARY)
  end

  it 'reads base64 split across lines, as Python and .NET do' do
    expect(MicrosoftKiotaSerializationJson::JsonParseNode.new("AP9I\nZWxsbw==").get_byte_array_value).to eq(bytes)
  end

  it 'reads nothing from a node that is not a string' do
    expect(MicrosoftKiotaSerializationJson::JsonParseNode.new(42).get_byte_array_value).to be_nil
    expect(MicrosoftKiotaSerializationJson::JsonParseNode.new(nil).get_byte_array_value).to be_nil
  end

  it 'reads back what it writes' do
    writer.write_byte_array_value('data', bytes)
    factory = MicrosoftKiotaSerializationJson::JsonParseNodeFactory.new
    node = factory.get_parse_node('application/json', writer.get_serialized_content)
    expect(node.get_child_node('data').get_byte_array_value).to eq(bytes)
  end
end
