# frozen_string_literal: true

require 'stringio'
require 'microsoft_kiota_abstractions'

RSpec.describe MicrosoftKiotaAbstractions::MultipartBody do
  subject(:body) { described_class.new }

  let(:calls) { [] }
  let(:writer) do
    recorded = calls
    double('writer').tap do |w|
      allow(w).to receive(:write_string_value) { |key, value| recorded << [:string, key, value] }
      allow(w).to receive(:write_byte_array_value) { |key, value| recorded << [:bytes, key, value] }
    end
  end
  let(:part_writer) { double('part writer') }
  let(:factory) { double('factory') }
  let(:adapter) { double('adapter', get_serialization_writer_factory: factory) }
  let(:model) { Class.new { include MicrosoftKiotaAbstractions::Parsable }.new }

  def part_header(name, content_type, disposition = %(form-data; name="#{name}"))
    [
      [:string, '', "--#{body.boundary}"],
      [:string, 'Content-Type', content_type],
      [:string, 'Content-Disposition', disposition],
      [:string, '', '']
    ]
  end

  def closing
    [[:string, '', ''], [:string, '', "--#{body.boundary}--"]]
  end

  it 'adds or replaces a part' do
    body.add_or_replace_part('text', 'text/plain', 'Hello, World!')
    expect(body.get_part_value('text')).to eq('Hello, World!')
    body.add_or_replace_part('text', 'text/plain', 'Hello, World! 2')
    expect(body.get_part_value('text')).to eq('Hello, World! 2')
  end

  it 'removes a part' do
    body.add_or_replace_part('text', 'text/plain', 'Hello, World!')
    expect(body.get_part_value('text')).to eq('Hello, World!')
    expect(body.remove_part('text')).to be(true)
    expect(body.get_part_value('text')).to be_nil
    expect(body.remove_part('text')).to be(false)
  end

  it 'looks parts up ignoring case' do
    body.add_or_replace_part('Text', 'text/plain', 'Hello')
    expect(body.get_part_value('TEXT')).to eq('Hello')
    expect(body.remove_part('text')).to be(true)
    expect(body.get_part_value('Text')).to be_nil
  end

  it 'does not deserialize' do
    expect { body.get_field_deserializers }.to raise_error(NotImplementedError)
  end

  it 'gives every body its own boundary' do
    expect(body.boundary).not_to be_empty
    expect(body.boundary).not_to eq(described_class.new.boundary)
  end

  describe '#serialize' do
    before { body.request_adapter = adapter }

    it 'writes a string part' do
      body.add_or_replace_part('message', 'text/plain', 'Hello world')
      body.serialize(writer)
      expect(calls).to eq(part_header('message', 'text/plain') + [[:bytes, '', 'Hello world']] + closing)
    end

    it 'writes an empty part, as an empty file upload is valid' do
      body.add_or_replace_part('file', 'application/octet-stream', '', 'empty.bin')
      body.serialize(writer)
      expect(calls).to eq(part_header('file', 'application/octet-stream', 'form-data; name="file"; filename="empty.bin"') +
                          [[:bytes, '', '']] + closing)
    end

    it 'writes the part name with its original casing' do
      body.add_or_replace_part('Message', 'text/plain', 'Hello world')
      body.serialize(writer)
      expect(calls).to include([:string, 'Content-Disposition', 'form-data; name="Message"'])
    end

    it 'keeps one part when it is replaced' do
      body.add_or_replace_part('message', 'text/plain', 'Hello')
      body.add_or_replace_part('Message', 'text/plain', 'Bye')
      body.serialize(writer)
      expect(calls).to eq(part_header('Message', 'text/plain') + [[:bytes, '', 'Bye']] + closing)
    end

    it 'writes the file name when set' do
      body.add_or_replace_part('file', 'application/octet-stream', 'data', 'file.txt')
      body.serialize(writer)
      expect(calls).to include([:string, 'Content-Disposition', 'form-data; name="file"; filename="file.txt"'])
    end

    it 'escapes quotes and line breaks in part names and file names, as browsers do' do
      body.add_or_replace_part('a"b', 'text/plain', 'data', %(my "best"\r\nnotes.txt))
      body.serialize(writer)
      expect(calls).to include([:string, 'Content-Disposition', 'form-data; name="a%22b"; filename="my %22best%22%0D%0Anotes.txt"'])
    end

    it 'reads a stream part from the start each time the body is written' do
      body.add_or_replace_part('file', 'application/octet-stream', StringIO.new('payload'))
      2.times { body.serialize(writer) }
      expect(calls.count([:bytes, '', 'payload'])).to eq(2)
    end

    it 'reads a stream part that cannot be rewound' do
      reader, writer_end = IO.pipe
      writer_end.write('piped')
      writer_end.close
      body.add_or_replace_part('file', 'application/octet-stream', reader)
      body.serialize(writer)
      expect(calls).to include([:bytes, '', 'piped'])
    end

    it 'reads a stream part' do
      body.add_or_replace_part('file', 'application/octet-stream', StringIO.new("\x00\x01".b))
      body.serialize(writer)
      expect(calls).to include([:bytes, '', "\x00\x01".b])
    end

    it 'writes a model part with a writer for the part content type' do
      allow(factory).to receive(:get_serialization_writer).with('application/json').and_return(part_writer)
      expect(part_writer).to receive(:write_object_value).with(nil, model)
      allow(part_writer).to receive(:get_serialized_content).and_return('{"id":1}')
      body.add_or_replace_part('user', 'application/json', model)
      body.add_or_replace_part('message', 'text/plain', 'Hello')
      body.serialize(writer)
      expect(calls).to eq(
        part_header('user', 'application/json') + [[:bytes, '', '{"id":1}'], [:string, '', '']] +
        part_header('message', 'text/plain') + [[:bytes, '', 'Hello']] + closing
      )
    end

    it 'reads a model part serialized to a stream' do
      allow(factory).to receive(:get_serialization_writer).and_return(part_writer)
      allow(part_writer).to receive(:write_object_value)
      content = StringIO.new('{"id":1}')
      content.read
      allow(part_writer).to receive(:get_serialized_content).and_return(content)
      body.add_or_replace_part('user', 'application/json', model)
      body.serialize(writer)
      expect(calls).to include([:bytes, '', '{"id":1}'])
    end

    it 'rejects a part of an unsupported type' do
      body.add_or_replace_part('count', 'text/plain', 42)
      expect { body.serialize(writer) }.to raise_error(ArgumentError, 'Unsupported type Integer for part count')
    end
  end
end

RSpec.describe MicrosoftKiotaAbstractions::MultipartBody, 'defensive checks' do
  subject(:body) { described_class.new }

  let(:writer) { double('writer') }
  let(:adapter) { double('adapter', get_serialization_writer_factory: double('factory')) }

  it 'rejects a missing part name, content type or value' do
    expect { body.add_or_replace_part(nil, 'text/plain', 'Hello, World!') }
      .to raise_error(ArgumentError, 'Part name cannot be null')
    expect { body.add_or_replace_part('text', nil, 'Hello, World!') }
      .to raise_error(ArgumentError, 'Content type cannot be null')
    expect { body.add_or_replace_part('text', 'text/plain', nil) }
      .to raise_error(ArgumentError, 'Part value cannot be null')
  end

  it 'rejects a content type with a line break, which would add headers to the part' do
    expect { body.add_or_replace_part('file', "text/plain\r\nX-Injected: 1", 'data') }
      .to raise_error(ArgumentError, 'Content type cannot contain line breaks')
  end

  it 'rejects an empty part name or content type' do
    expect { body.add_or_replace_part('', 'text/plain', 'Hello') }.to raise_error(ArgumentError, 'Part name cannot be null')
    expect { body.add_or_replace_part('text', '', 'Hello') }.to raise_error(ArgumentError, 'Content type cannot be null')
  end

  it 'rejects a missing part name when reading or removing a part' do
    [nil, ''].each do |name|
      expect { body.get_part_value(name) }.to raise_error(ArgumentError, 'Part name cannot be null')
      expect { body.remove_part(name) }.to raise_error(ArgumentError, 'Part name cannot be null')
    end
  end

  it 'rejects a missing writer' do
    expect { body.serialize(nil) }.to raise_error(ArgumentError, 'Serialization writer cannot be null')
  end

  it 'rejects a missing request adapter or serialization writer factory' do
    body.add_or_replace_part('text', 'text/plain', 'Hello')
    expect { body.serialize(writer) }
      .to raise_error(ArgumentError, 'Request adapter or serialization writer factory cannot be null')
    body.request_adapter = double('adapter', get_serialization_writer_factory: nil)
    expect { body.serialize(writer) }
      .to raise_error(ArgumentError, 'Request adapter or serialization writer factory cannot be null')
  end

  it 'rejects a body without parts' do
    body.request_adapter = adapter
    expect { body.serialize(writer) }.to raise_error(ArgumentError, 'No parts to serialize')
  end
end
