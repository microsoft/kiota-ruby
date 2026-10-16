# frozen_string_literal: true

require 'uuidtools'
require_relative 'spec_helper'
require_relative 'files/test_entity'
require 'microsoft_kiota_serialization_json'

RSpec.describe 'a multipart request body' do
  let(:registry) do
    MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.new.tap do |r|
      r.content_type_associated_factories['multipart/form-data'] =
        MicrosoftKiotaSerializationMultipart::MultipartSerializationWriterFactory.new
      r.content_type_associated_factories['application/json'] =
        MicrosoftKiotaSerializationJson::JsonSerializationWriterFactory.new
    end
  end
  let(:adapter) { double('request adapter', get_serialization_writer_factory: registry) }
  let(:user) do
    Files::TestEntity.new.tap { |u| u.id = UUIDTools::UUID.parse('eac79bd3-fd08-4abf-9df2-2565cf3a3845') }
  end

  it 'is written with the factory registered for each part and sent with its boundary' do
    body = MicrosoftKiotaAbstractions::MultipartBody.new
    body.add_or_replace_part('test user', 'application/json', user)
    body.add_or_replace_part('message', 'text/plain', 'Hello world')
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.set_content_from_parsable(adapter, 'multipart/form-data', body)

    expect(request_info.headers.get('Content-Type')).to eq(["multipart/form-data; boundary=#{body.boundary}"])
    expect(request_info.content).to eq(
      "--#{body.boundary}\r\nContent-Type: application/json\r\nContent-Disposition: form-data; name=\"test user\"" \
      "\r\n\r\n{\"id\":\"eac79bd3-fd08-4abf-9df2-2565cf3a3845\"}\r\n--#{body.boundary}\r\nContent-Type: text/plain" \
      "\r\nContent-Disposition: form-data; name=\"message\"\r\n\r\nHello world\r\n--#{body.boundary}--\r\n"
    )
  end
end
