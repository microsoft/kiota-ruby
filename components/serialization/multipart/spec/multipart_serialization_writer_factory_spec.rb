# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe MicrosoftKiotaSerializationMultipart::MultipartSerializationWriterFactory do
  subject(:factory) { described_class.new }

  it 'creates a multipart writer' do
    expect(factory.get_serialization_writer('multipart/form-data'))
      .to be_a(MicrosoftKiotaSerializationMultipart::MultipartSerializationWriter)
  end

  it 'matches the content type ignoring case' do
    expect(factory.get_serialization_writer('Multipart/Form-Data'))
      .to be_a(MicrosoftKiotaSerializationMultipart::MultipartSerializationWriter)
  end

  it 'rejects a missing content type' do
    expect { factory.get_serialization_writer('') }.to raise_error(ArgumentError, 'content type cannot be undefined or empty')
    expect { factory.get_serialization_writer(nil) }.to raise_error(ArgumentError, 'content type cannot be undefined or empty')
  end

  it 'rejects an unsupported content type' do
    expect { factory.get_serialization_writer('application/xml') }
      .to raise_error(ArgumentError, 'expected a multipart/form-data content type')
  end

  it 'gives the content type it writes' do
    expect(factory.get_valid_content_type).to eq('multipart/form-data')
  end
end
