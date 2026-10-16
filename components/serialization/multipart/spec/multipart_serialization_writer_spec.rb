# frozen_string_literal: true

require 'date'
require 'uuidtools'
require_relative 'spec_helper'
require_relative 'files/test_entity'
require 'microsoft_kiota_serialization_json'

RSpec.describe MicrosoftKiotaSerializationMultipart::MultipartSerializationWriter do
  subject(:writer) { described_class.new }

  let(:json_factory) { MicrosoftKiotaSerializationJson::JsonSerializationWriterFactory.new }
  let(:request_adapter) { double('request adapter', get_serialization_writer_factory: json_factory) }
  let(:body) do
    MicrosoftKiotaAbstractions::MultipartBody.new.tap { |b| b.request_adapter = request_adapter }
  end
  let(:user) do
    Files::TestEntity.new.tap do |u|
      u.id = UUIDTools::UUID.parse('eac79bd3-fd08-4abf-9df2-2565cf3a3845')
      u.birthday = Date.new(2017, 9, 4)
      u.work_duration = MicrosoftKiotaAbstractions::ISODuration.new('PT2H')
      u.additional_data = { 'businessPhones' => ['+1 412 555 0109'], 'mobilePhone' => nil, 'jobTitle' => 'Auditor' }
    end
  end
  let(:user_json) do
    '{"id":"eac79bd3-fd08-4abf-9df2-2565cf3a3845","birthDay":"2017-09-04","workDuration":"PT2H",' \
      '"businessPhones":["+1 412 555 0109"],"mobilePhone":null,"jobTitle":"Auditor"}'
  end

  def part(name, content_type, content, filename: nil)
    disposition = %(form-data; name="#{name}")
    disposition += %(; filename="#{filename}") if filename
    "--#{body.boundary}\r\nContent-Type: #{content_type}\r\nContent-Disposition: #{disposition}\r\n\r\n#{content}\r\n"
  end

  def closing
    "--#{body.boundary}--\r\n"
  end

  it 'does not implement the other writers' do
    expect { writer.write_boolean_value('isActive', false) }.to raise_error(NotImplementedError)
    expect { writer.write_number_value('count', 0) }.to raise_error(NotImplementedError)
    expect { writer.write_float_value('gpa', 0.0) }.to raise_error(NotImplementedError)
    expect { writer.write_guid_value('id', UUIDTools::UUID.random_create) }.to raise_error(NotImplementedError)
    expect { writer.write_date_value('birthday', Date.new(2000, 9, 4)) }.to raise_error(NotImplementedError)
    expect { writer.write_time_value('time', Time.now) }.to raise_error(NotImplementedError)
    expect { writer.write_date_time_value('updatedAt', DateTime.now) }.to raise_error(NotImplementedError)
    expect { writer.write_duration_value('diff', MicrosoftKiotaAbstractions::ISODuration.new('PT2H')) }
      .to raise_error(NotImplementedError)
    expect { writer.write_enum_value('number', :four) }.to raise_error(NotImplementedError)
    expect { writer.write_collection_of_primitive_values('numbers', [1, 2.0, '3']) }.to raise_error(NotImplementedError)
    expect { writer.write_collection_of_object_values('users', [user]) }.to raise_error(NotImplementedError)
    expect { writer.write_collection_of_enum_values('numbers', %i[four eight]) }.to raise_error(NotImplementedError)
    expect { writer.write_null_value('nothing') }.to raise_error(NotImplementedError)
    expect { writer.write_additional_data({ 'a' => 1 }) }.to raise_error(NotImplementedError)
    expect { writer.write_any_value('a', 1) }.to raise_error(NotImplementedError)
  end

  it 'writes a string value' do
    writer.write_string_value('message', 'Hello world')
    expect(writer.get_serialized_content).to eq("message: Hello world\r\n")
  end

  it 'writes a line with only a key or only a value' do
    writer.write_string_value('', '--boundary')
    writer.write_string_value('key', nil)
    writer.write_string_value('', '')
    expect(writer.get_serialized_content).to eq("--boundary\r\nkey\r\n\r\n")
  end

  it 'writes bytes as they are' do
    writer.write_byte_array_value('', 'Hello world')
    writer.write_byte_array_value('', nil)
    expect(writer.get_serialized_content).to eq('Hello world')
  end

  it 'raises for a model that is not a multipart body' do
    expect { writer.write_object_value('user', user) }
      .to raise_error(ArgumentError, /Expected a MultipartBody instance but got Files::TestEntity/)
  end

  it 'writes a model part and a binary part' do
    body.add_or_replace_part('test user', 'application/json', user)
    body.add_or_replace_part('img', 'application/octet-stream', 'Hello world'.b)
    writer.write_object_value('', body, nil)
    expect(writer.get_serialized_content)
      .to eq(part('test user', 'application/json', user_json) + part('img', 'application/octet-stream', 'Hello world') + closing)
  end

  it 'writes the parts in the order they were added' do
    body.add_or_replace_part('img', 'application/octet-stream', 'Hello world'.b)
    body.add_or_replace_part('test user', 'application/json', user)
    writer.write_object_value('', body, nil)
    expect(writer.get_serialized_content)
      .to eq(part('img', 'application/octet-stream', 'Hello world') + part('test user', 'application/json', user_json) + closing)
  end

  it 'writes the file name of a part' do
    body.add_or_replace_part('test user', 'application/json', user)
    body.add_or_replace_part('file', 'application/octet-stream', 'Hello world'.b, 'file.txt')
    writer.write_object_value('', body, nil)
    expect(writer.get_serialized_content).to eq(
      part('test user', 'application/json', user_json) +
      part('file', 'application/octet-stream', 'Hello world', filename: 'file.txt') + closing
    )
  end

  it 'writes a string part' do
    body.add_or_replace_part('message', 'text/plain', 'Hello world')
    writer.write_object_value('', body, nil)
    expect(writer.get_serialized_content).to eq(
      "--#{body.boundary}\r\nContent-Type: text/plain\r\nContent-Disposition: form-data; name=\"message\"\r\n\r\n" \
      "Hello world\r\n--#{body.boundary}--\r\n"
    )
  end

  it 'writes several string parts' do
    body.add_or_replace_part('message1', 'text/plain', 'Hello world')
    body.add_or_replace_part('message2', 'text/plain', 'Goodbye world')
    writer.write_object_value('', body, nil)
    expect(writer.get_serialized_content)
      .to eq(part('message1', 'text/plain', 'Hello world') + part('message2', 'text/plain', 'Goodbye world') + closing)
  end

  it 'writes a stream part' do
    body.add_or_replace_part('file', 'application/octet-stream', StringIO.new('Hello world'))
    writer.write_object_value('', body)
    expect(writer.get_serialized_content).to eq(part('file', 'application/octet-stream', 'Hello world') + closing)
  end

  it 'mixes UTF-8 text with raw bytes' do
    user.display_name = 'Zoë ☃'
    binary = "\xFF\xD8\xFF\x00".b
    body.add_or_replace_part('test user', 'application/json', user)
    body.add_or_replace_part('note', 'text/plain', 'héllo')
    body.add_or_replace_part('img', 'image/jpeg', binary)
    writer.write_object_value('', body)
    content = writer.get_serialized_content
    expect(content.encoding).to eq(Encoding::BINARY)
    expect(content).to eq(
      part('test user', 'application/json', user_json.sub('"birthDay"', '"displayName":"Zoë ☃","birthDay"')).b +
      part('note', 'text/plain', 'héllo').b + part('img', 'image/jpeg', binary) + closing
    )
  end

  it 'calls the serialization hooks around the body' do
    calls = []
    writer.on_before_object_serialization = ->(value) { calls << [:before, value] }
    writer.on_start_object_serialization = ->(value, w) { calls << [:start, value, w] }
    writer.on_after_object_serialization = ->(value) { calls << [:after, value] }
    body.add_or_replace_part('message', 'text/plain', 'Hello world')
    writer.write_object_value('', body)
    expect(calls).to eq([[:before, body], [:start, body, writer], [:after, body]])
  end

  it 'calls the after hook when writing the body raises' do
    calls = []
    writer.on_after_object_serialization = ->(value) { calls << value }
    expect { writer.write_object_value('', body) }.to raise_error(ArgumentError, 'No parts to serialize')
    expect(calls).to eq([body])
  end
end
