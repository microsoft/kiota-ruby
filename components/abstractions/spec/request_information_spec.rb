# frozen_string_literal: true

require 'microsoft_kiota_abstractions'
require_relative 'request_option_mock'
require_relative 'query_parameters_mock'

RSpec.describe MicrosoftKiotaAbstractions do
  it 'adds a request option to the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    mock_option = RequestOptionMock.new
    mock_option.value = 'value'
    request_info.add_request_options(mock_option)
    expect(request_info.get_request_options.length).to eq(1)
    expect(request_info.get_request_option('key')).to eq(mock_option)
  end

  it 'removes a request option from the request information' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    mock_option = RequestOptionMock.new
    mock_option.value = 'value'
    request_info.add_request_options(mock_option)
    expect(request_info.get_request_options.length).to eq(1)
    request_info.remove_request_options('key')
    expect(request_info.get_request_options.length).to eq(0)
  end

  it 'adds query parameters with their escaped values' do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    query_parameters = QueryParametersMock.new
    query_parameters.select = 'foo,bar'
    request_info.set_query_string_parameters_from_raw_object(query_parameters)
    expect(request_info.query_parameters.length).to eq(1)
    expect(request_info.query_parameters['%24select']).to eq('foo,bar')
    expect(request_info.query_parameters['select']).to be_nil
  end

  it "doesn't fail adding query parameters with anonymous object" do
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    query_parameters = {
      select: 'foo,bar'
    }
    request_info.set_query_string_parameters_from_raw_object(query_parameters)
    expect(request_info.query_parameters.length).to eq(0)
  end

  it 'sets the boundary on a multipart request body' do
    writer = double('writer', write_object_value: nil, get_serialized_content: 'content')
    factory = double('factory')
    allow(factory).to receive(:get_serialization_writer).with('multipart/form-data').and_return(writer)
    adapter = double('adapter', get_serialization_writer_factory: factory)
    body = MicrosoftKiotaAbstractions::MultipartBody.new
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.set_content_from_parsable(adapter, 'multipart/form-data', body)
    expect(request_info.headers.get('Content-Type')).to eq(["multipart/form-data; boundary=#{body.boundary}"])
    expect(body.request_adapter).to be(adapter)
    expect(writer).to have_received(:write_object_value).with(nil, body)
  end

  it 'replaces a content type set beforehand with one carrying the boundary' do
    writer = double('writer', write_object_value: nil, get_serialized_content: 'content')
    adapter = double('adapter', get_serialization_writer_factory: double('factory', get_serialization_writer: writer))
    body = MicrosoftKiotaAbstractions::MultipartBody.new
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.headers.add('Content-Type', 'multipart/form-data')
    request_info.set_content_from_parsable(adapter, 'multipart/form-data', body)
    expect(request_info.headers.get('Content-Type')).to eq(["multipart/form-data; boundary=#{body.boundary}"])
  end

  it 'replaces a boundary given in the content type with the body boundary' do
    writer = double('writer', write_object_value: nil, get_serialized_content: 'content')
    adapter = double('adapter', get_serialization_writer_factory: double('factory', get_serialization_writer: writer))
    body = MicrosoftKiotaAbstractions::MultipartBody.new
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.set_content_from_parsable(adapter, 'multipart/form-data; Boundary="old"; charset=utf-8', body)
    expect(request_info.headers.get('Content-Type')).to eq(["multipart/form-data; charset=utf-8; boundary=#{body.boundary}"])
  end

  it 'loads the multipart body it checks for when required on its own' do
    file = File.expand_path('../lib/microsoft_kiota_abstractions/request_information', __dir__)
    out = IO.popen([RbConfig.ruby, '-e', "require '#{file}'; print defined?(MicrosoftKiotaAbstractions::MultipartBody)"], &:read)
    expect(out).to eq('constant')
  end

  it 'leaves the content type of any other body alone' do
    writer = double('writer', write_object_value: nil, get_serialized_content: '{}')
    adapter = double('adapter', get_serialization_writer_factory: double('factory', get_serialization_writer: writer))
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    request_info.set_content_from_parsable(adapter, 'application/json', Class.new { include MicrosoftKiotaAbstractions::Parsable }.new)
    expect(request_info.headers.get('Content-Type')).to eq(['application/json'])
  end

  it 'keeps the error of a content type without a serialization writer' do
    factory = double('factory')
    allow(factory).to receive(:get_serialization_writer)
      .and_raise(ArgumentError, 'Content type text/csv does not have a factory to be serialized')
    adapter = double('adapter', get_serialization_writer_factory: factory)
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    body = Class.new { include MicrosoftKiotaAbstractions::Parsable }.new
    expect { request_info.set_content_from_parsable(adapter, 'text/csv', body) }
      .to raise_error(ArgumentError, 'Content type text/csv does not have a factory to be serialized')
  end

  it 'keeps the error of a multipart body without parts' do
    writer = double('writer', get_serialized_content: 'content')
    allow(writer).to receive(:write_object_value) { |_key, value| value.serialize(writer) }
    adapter = double('adapter', get_serialization_writer_factory: double('factory', get_serialization_writer: writer))
    request_info = MicrosoftKiotaAbstractions::RequestInformation.new
    body = MicrosoftKiotaAbstractions::MultipartBody.new
    expect { request_info.set_content_from_parsable(adapter, 'multipart/form-data', body) }
      .to raise_error(ArgumentError, 'No parts to serialize')
  end
end
