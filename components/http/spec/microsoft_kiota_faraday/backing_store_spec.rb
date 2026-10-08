# frozen_string_literal: true

RSpec.describe MicrosoftKiotaFaraday::FaradayRequestAdapter do
  subject(:adapter) { described_class.new(double('authentication_provider'), parse_nodes, writers) }

  let(:json_type) { 'application/json' }
  let(:parse_nodes) { MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.new }
  let(:writers) { MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.new }

  before do
    parse_nodes.content_type_associated_factories[json_type] = double('json parse node factory')
    writers.content_type_associated_factories[json_type] = double('json writer factory')
  end

  after { MicrosoftKiotaAbstractions::BackingStoreFactorySingleton.instance = nil }

  describe '#enable_backing_store' do
    it 'wraps the factories it reads and writes with' do
      adapter.enable_backing_store
      expect(parse_nodes.content_type_associated_factories[json_type]).to be_a(MicrosoftKiotaAbstractions::BackingStoreParseNodeFactory)
      expect(writers.content_type_associated_factories[json_type])
        .to be_a(MicrosoftKiotaAbstractions::BackingStoreSerializationWriterProxyFactory)
    end

    it 'uses the backing store factory it is given' do
      factory = double('backing store factory')
      adapter.enable_backing_store(factory)
      expect(MicrosoftKiotaAbstractions::BackingStoreFactorySingleton.instance).to be(factory)
    end
  end
end
