# frozen_string_literal: true

require_relative 'spec_helper'
require_relative 'files/files'

RSpec.describe MicrosoftKiotaSerializationText::TextParseNode do
  let(:structured_data_error) { [StandardError, 'Text does not support structured data'] }
  let(:user_factory) { ->(pn) { Files::User.create_from_discriminator_value(pn) } }
  let(:sample_structured_data) do
    '{"@odata.context": "https://graph.microsoft.com/v1.0/$metadata#users/$entity", ' \
      '"businessPhones": ["+1 425 555 0109"], "displayName": "Adele Vance", "mobilePhone": null, ' \
      '"officeLocation": "dunhill", "updatedAt": "2017 -07-29T03:07:25Z", "birthday": "2000-09-04", ' \
      '"isActive": true, "age": 21, "gpa": 3.7, "id": "76cabd60-f9aa-4d23-8958-64f5539b826a"}'
  end

  it 'gets a string value' do
    expect(described_class.new('Diego Siciliani').get_string_value).to eq('Diego Siciliani')
  end

  it 'gets a number value' do
    expect(described_class.new('1454').get_number_value).to eq(1454)
  end

  it 'gets a boolean value' do
    expect(described_class.new('false').get_boolean_value).to be(false)
  end

  it 'gets a float value' do
    expect(described_class.new('44.6').get_float_value).to eq(44.6)
  end

  it 'gets a guid value' do
    result = described_class.new('f58411c7-ae78-4d3c-bb0d-3f24d948de41').get_guid_value
    expect(result).to eq(UUIDTools::UUID.parse('f58411c7-ae78-4d3c-bb0d-3f24d948de41'))
  end

  it 'gets a date time value' do
    expect(described_class.new('2022-01-27T12:59:45.596117').get_date_time_value).to be_a(DateTime)
  end

  it 'gets a date value' do
    result = described_class.new('2015-04-20').get_date_value
    expect(result).to be_a(Date)
    expect(result.to_s).to eq('2015-04-20')
  end

  it 'gets a time value' do
    result = described_class.new('12:59:45.596117').get_time_value
    expect(result).to be_a(Time)
    expect(result.strftime('%H:%M:%S.%6N')).to eq('12:59:45.596117')
  end

  it 'gets a duration value' do
    result = described_class.new('PT12H59M45S').get_duration_value
    expect(result).to be_a(MicrosoftKiotaAbstractions::ISODuration)
    expect([result.hours, result.minutes, result.seconds]).to eq([12, 59, 45])
  end

  it 'raises when getting a collection of primitive values' do
    parse_node = described_class.new('[12.1, 12.2, 12.3, 12.4, 12.5]')
    expect { parse_node.get_collection_of_primitive_values(Float) }.to raise_error(*structured_data_error)
  end

  it 'gets a byte array value' do
    result = described_class.new('U2Ftd2VsIGlzIHRoZSBiZXN0').get_byte_array_value
    expect(result).to be_a(String)
    expect(result).to eq('Samwel is the best')
  end

  it 'raises when getting a collection of enum values' do
    parse_node = described_class.new('dunhill,oval')
    expect { parse_node.get_collection_of_enum_values(Files::OFFICE_LOCATION) }.to raise_error(*structured_data_error)
  end

  it 'gets an enum value' do
    expect(described_class.new('dunhill').get_enum_value(Files::OFFICE_LOCATION)).to eq(Files::OFFICE_LOCATION[:Dunhill])
  end

  it 'raises when getting an object value' do
    parse_node = described_class.new(sample_structured_data)
    expect { parse_node.get_object_value(user_factory) }.to raise_error(*structured_data_error)
  end

  it 'raises when getting a collection of object values' do
    parse_node = described_class.new(sample_structured_data)
    expect { parse_node.get_collection_of_object_values(user_factory) }.to raise_error(*structured_data_error)
  end

  it 'raises when getting a child node' do
    expect { described_class.new(sample_structured_data).get_child_node('displayName') }.to raise_error(*structured_data_error)
  end

  describe 'edge cases' do
    it 'reads false as false rather than as a non-empty string' do
      expect(described_class.new('FALSE').get_boolean_value).to be(false)
      expect(described_class.new('True').get_boolean_value).to be(true)
      expect(described_class.new('yes').get_boolean_value).to be_nil
    end

    it 'reads an enum member by its wire value' do
      access = { IncomingPayment: 'incoming-payment', ReadAll: 'read-all' }.freeze
      expect(described_class.new('incoming-payment').get_enum_value(access)).to eq(access[:IncomingPayment])
    end

    it 'returns nil for an enum member the enum does not declare' do
      expect(described_class.new('purple').get_enum_value(Files::OFFICE_LOCATION)).to be_nil
    end

    it 'returns nil from every reader for empty or missing text' do
      ['', nil].each do |text|
        parse_node = described_class.new(text)
        readers = %i[get_string_value get_boolean_value get_number_value get_float_value get_guid_value get_date_value
                     get_time_value get_date_time_value get_duration_value get_byte_array_value]
        readers.each { |reader| expect(parse_node.public_send(reader)).to be_nil, "#{reader} on #{text.inspect}" }
        expect(parse_node.get_enum_value(Files::OFFICE_LOCATION)).to be_nil
      end
    end

    it 'ignores surrounding whitespace in typed values but not in strings' do
      expect(described_class.new("true\n").get_boolean_value).to be(true)
      expect(described_class.new(" 42\n").get_number_value).to eq(42)
      expect(described_class.new("f58411c7-ae78-4d3c-bb0d-3f24d948de41\r\n").get_guid_value)
        .to eq(UUIDTools::UUID.parse('f58411c7-ae78-4d3c-bb0d-3f24d948de41'))
      expect(described_class.new("dunhill\n").get_enum_value(Files::OFFICE_LOCATION)).to eq(Files::OFFICE_LOCATION[:Dunhill])
      expect(described_class.new("hi\n").get_string_value).to eq("hi\n")
    end

    it 'returns nil from typed readers for blank text' do
      parse_node = described_class.new(" \n")
      readers = %i[get_boolean_value get_number_value get_float_value get_guid_value get_date_value get_time_value
                   get_date_time_value get_duration_value get_byte_array_value]
      readers.each { |reader| expect(parse_node.public_send(reader)).to be_nil, reader.to_s }
    end

    it 'reads a date, time or date time only in its own shape, as the form gem does' do
      date, date_time, time = %w[2017-09-04 2017-07-29T03:07:25Z 08:00:00].map { |text| described_class.new(text) }
      expect([date.get_date_value, date.get_date_time_value, date.get_time_value]).to eq([Date.new(2017, 9, 4), nil, nil])
      expect([date_time.get_date_value, date_time.get_time_value]).to eq([nil, nil])
      expect(date_time.get_date_time_value).to eq(DateTime.new(2017, 7, 29, 3, 7, 25))
      expect([time.get_date_value, time.get_date_time_value]).to eq([nil, nil])
      expect(time.get_time_value.strftime('%H:%M:%S')).to eq('08:00:00')
    end

    it 'reads a date time with a space separator, like the JSON gem' do
      expect(described_class.new('2024-01-02 03:04:05Z').get_date_time_value).to eq(DateTime.new(2024, 1, 2, 3, 4, 5))
    end

    it 'reads base64 split across lines, as Python and .NET do' do
      expect(described_class.new("U2Ftd2Vs\nIGlzIHRoZSBiZXN0").get_byte_array_value).to eq('Samwel is the best')
    end

    it 'returns nil for text that is not a guid, date, time, date time or duration, as .NET and the form gem do' do
      parse_node = described_class.new('not a value')
      readers = %i[get_guid_value get_date_value get_time_value get_date_time_value get_duration_value]
      readers.each { |reader| expect(parse_node.public_send(reader)).to be_nil, reader.to_s }
    end

    it 'returns nil for text that is not a number' do
      expect(described_class.new('twelve').get_number_value).to be_nil
      expect(described_class.new('12.5').get_number_value).to be_nil
      expect(described_class.new('twelve').get_float_value).to be_nil
    end
  end
end
