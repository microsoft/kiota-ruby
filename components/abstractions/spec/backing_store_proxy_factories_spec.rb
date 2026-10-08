# frozen_string_literal: true

require 'microsoft_kiota_abstractions'

module ProxyFactoryFakes
  Node = Struct.new(:on_before_assign_field_values, :on_after_assign_field_values)
  Writer = Struct.new(:on_before_object_serialization, :on_after_object_serialization,
                      :on_start_object_serialization, :nulls) do
    def write_null_value(key) = (self.nulls ||= []) << key
  end

  ParseFactory = Struct.new(:content_type) do
    def get_valid_content_type = content_type
    def get_parse_node(_content_type, _content) = Node.new
  end

  WriterFactory = Struct.new(:content_type) do
    def get_valid_content_type = content_type
    def get_serialization_writer(_content_type) = Writer.new
  end

  class Model
    include MicrosoftKiotaAbstractions::BackedModel

    def initialize = @backing_store = MicrosoftKiotaAbstractions::InMemoryBackingStore.new
  end
end

RSpec.describe MicrosoftKiotaAbstractions::BackingStoreParseNodeFactory do
  it 'tracks changes only once the model has been filled' do
    node = described_class.new(ProxyFactoryFakes::ParseFactory.new('application/json')).get_parse_node('application/json', '{}')
    model = ProxyFactoryFakes::Model.new
    node.on_before_assign_field_values.call(model)
    expect(model.backing_store.initialization_completed).to be(false)
    node.on_after_assign_field_values.call(model)
    expect(model.backing_store.initialization_completed).to be(true)
  end

  it 'keeps the callbacks the node already had' do
    calls = []
    factory = Class.new(ProxyFactoryFakes::ParseFactory) do
      define_method(:get_parse_node) { |*| ProxyFactoryFakes::Node.new(->(_) { calls << :before }, nil) }
    end
    node = described_class.new(factory.new('application/json')).get_parse_node('application/json', '{}')
    node.on_before_assign_field_values.call(ProxyFactoryFakes::Model.new)
    expect(calls).to eq([:before])
  end
end

RSpec.describe MicrosoftKiotaAbstractions::BackingStoreSerializationWriterProxyFactory do
  subject(:writer) { described_class.new(ProxyFactoryFakes::WriterFactory.new('application/json')).get_serialization_writer('application/json') }

  let(:model) do
    ProxyFactoryFakes::Model.new.tap do |m|
      m.backing_store.set('name', 'a')
      m.backing_store.set('phone', '1')
      m.backing_store.initialization_completed = true
      m.backing_store.set('phone', nil)
    end
  end

  it 'returns only changed values while the model is written, and all of them after' do
    writer.on_before_object_serialization.call(model)
    expect(model.backing_store.enumerate).to eq([['phone', nil]])
    writer.on_after_object_serialization.call(model)
    expect(model.backing_store.enumerate.size).to eq(2)
  end

  it 'writes a null for every value changed to nil' do
    writer.on_start_object_serialization.call(model, writer)
    expect(writer.nulls).to eq(['phone'])
  end
end

RSpec.describe MicrosoftKiotaAbstractions::ApiClientBuilder do
  around do |example|
    registries = [MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance,
                  MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.default_instance]
    saved = registries.map { |r| r.content_type_associated_factories.dup }
    example.run
  ensure
    registries.zip(saved).each { |registry, factories| registry.content_type_associated_factories.replace(factories) }
  end

  it 'wraps every factory registered by default, once' do
    MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance.content_type_associated_factories['application/json'] =
      ProxyFactoryFakes::ParseFactory.new('application/json')
    registry = MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance
    2.times { described_class.enable_backing_store_for_parse_node_factory(registry) }
    expect(registry.content_type_associated_factories['application/json']).to be_a(MicrosoftKiotaAbstractions::BackingStoreParseNodeFactory)
    expect(registry.content_type_associated_factories['application/json'].instance_variable_get(:@concrete))
      .to be_a(ProxyFactoryFakes::ParseFactory)
  end

  it 'does not wrap a factory twice' do
    once = described_class.enable_backing_store_for_serialization_writer_factory(ProxyFactoryFakes::WriterFactory.new('text/plain'))
    expect(described_class.enable_backing_store_for_serialization_writer_factory(once)).to be(once)
    parse_once = described_class.enable_backing_store_for_parse_node_factory(ProxyFactoryFakes::ParseFactory.new('text/plain'))
    expect(described_class.enable_backing_store_for_parse_node_factory(parse_once)).to be(parse_once)
  end

  it 'wraps a factory that is not a registry' do
    result = described_class.enable_backing_store_for_serialization_writer_factory(ProxyFactoryFakes::WriterFactory.new('text/plain'))
    expect(result).to be_a(MicrosoftKiotaAbstractions::BackingStoreSerializationWriterProxyFactory)
  end
end
