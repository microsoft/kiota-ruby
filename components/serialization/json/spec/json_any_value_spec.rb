# frozen_string_literal: true

require_relative 'spec_helper'
require 'microsoft_kiota_abstractions'

module AnyValueModels
  class Named
    include MicrosoftKiotaAbstractions::Parsable

    attr_accessor :name

    def initialize(name = nil)
      @name = name
    end

    def get_field_deserializers = { 'name' => ->(n) { @name = n.get_string_value } }
    def serialize(writer) = writer.write_string_value('name', @name)
  end

  class Label < String; end

  # a composed type wrapper holding a scalar writes it as the root value
  class Wrapper
    include MicrosoftKiotaAbstractions::Parsable

    def get_field_deserializers = {}
    def serialize(writer) = writer.write_string_value(nil, 'hello')
  end
end

RSpec.describe 'serializing any value' do
  let(:writer) { MicrosoftKiotaSerializationJson::JsonSerializationWriter.new }
  let(:uuid) { UUIDTools::UUID.parse('2b6d5c1e-8f3a-4d2b-9c7e-1a2b3c4d5e6f') }

  def serialized(data)
    writer.write_additional_data(data)
    JSON.parse(writer.get_serialized_content)
  end

  describe 'in additional data' do
    it 'writes true' do
      expect(serialized('flag' => true)).to eq({ 'flag' => true })
    end

    it 'writes false rather than null' do
      expect(serialized('flag' => false)).to eq({ 'flag' => false })
    end

    it 'writes nil as null' do
      expect(serialized('gone' => nil)).to eq({ 'gone' => nil })
    end

    it 'writes a guid as its string' do
      expect(serialized('id' => uuid)).to eq({ 'id' => uuid.to_s })
    end

    it 'writes a symbol, as an enum member is read, as its name' do
      expect(serialized('colour' => :Red)).to eq({ 'colour' => 'Red' })
    end

    it 'writes a nested object, including an array of objects, as read from JSON' do
      nested = JSON.parse('{"a": 1, "b": {"c": [true, false, null, {"d": "e"}]}}')
      expect(serialized('nested' => nested)).to eq({ 'nested' => nested })
    end

    it 'writes strings, integers and floats' do
      expect(serialized('s' => 'x', 'i' => 1, 'f' => 1.5)).to eq({ 's' => 'x', 'i' => 1, 'f' => 1.5 })
    end

    it 'writes a String subclass as a string' do
      expect(serialized('label' => AnyValueModels::Label.new('x'))).to eq({ 'label' => 'x' })
    end

    it 'writes a date, a date time and a duration' do
      data = {
        'day' => Date.new(2026, 1, 2),
        'at' => DateTime.new(2026, 1, 2, 3, 4, 5),
        'length' => MicrosoftKiotaAbstractions::ISODuration.new('PT3H12M5S')
      }
      expect(serialized(data)).to eq({ 'day' => '2026-01-02', 'at' => '2026-01-02T03:04:05+00:00', 'length' => 'PT3H12M5S' })
    end

    it 'writes a model as a nested object' do
      expect(serialized('owner' => AnyValueModels::Named.new('x'))).to eq({ 'owner' => { 'name' => 'x' } })
    end

    it 'writes a wrapper holding a scalar as that scalar' do
      expect(serialized('direct' => AnyValueModels::Wrapper.new)).to eq({ 'direct' => 'hello' })
    end

    it 'converts the values in a collection' do
      data = { 'arr' => [true, false, nil, { 'a' => 1 }, :Red, uuid] }
      expect(serialized(data)).to eq({ 'arr' => [true, false, nil, { 'a' => 1 }, 'Red', uuid.to_s] })
    end

    it 'raises on a value of an unknown type' do
      expect { writer.write_additional_data('third' => Rational(1, 3)) }
        .to raise_error(StandardError, 'Encountered an unknown type during serialization Rational with key third')
    end
  end

  describe 'in a keyed collection of primitives' do
    it 'keeps false, nil and objects' do
      writer.write_collection_of_primitive_values('values', [false, nil, { 'a' => [{ 'b' => 2 }] }])
      expect(JSON.parse(writer.get_serialized_content)).to eq({ 'values' => [false, nil, { 'a' => [{ 'b' => 2 }] }] })
    end
  end

  describe 'with a nil key' do
    it 'writes false as the root of the document' do
      writer.write_any_value(nil, false)
      expect(JSON.parse(writer.get_serialized_content)).to be(false)
    end

    it 'writes an object as the root of the document' do
      writer.write_any_value(nil, { 'a' => [1, { 'b' => nil }] })
      expect(JSON.parse(writer.get_serialized_content)).to eq({ 'a' => [1, { 'b' => nil }] })
    end

    it 'writes a collection holding objects as the root of the document' do
      writer.write_collection_of_primitive_values(nil, [false, { 'a' => 1 }])
      expect(JSON.parse(writer.get_serialized_content)).to eq([false, { 'a' => 1 }])
    end
  end
end
