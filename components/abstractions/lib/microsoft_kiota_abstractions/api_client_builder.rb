# frozen_string_literal: true

require_relative 'serialization/parse_node_factory'
require_relative 'serialization/parse_node_factory_registry'
require_relative 'serialization/serialization_writer_factory'
require_relative 'serialization/serialization_writer_factory_registry'
require_relative 'store/backing_store_parse_node_factory'
require_relative 'store/backing_store_serialization_writer_proxy_factory'

module MicrosoftKiotaAbstractions
  class ApiClientBuilder
    def self.register_default_serializer(factory_class)
      factory = factory_class.new
      MicrosoftKiotaAbstractions::SerializationWriterFactoryRegistry.default_instance.content_type_associated_factories[factory.get_valid_content_type] =
        factory
    end

    # wraps the factory, and every factory registered by default, so models write only their changed values
    def self.enable_backing_store_for_serialization_writer_factory(original)
      result = original
      if original.is_a?(SerializationWriterFactoryRegistry)
        enable_backing_store_for_registry(original, BackingStoreSerializationWriterProxyFactory)
      elsif !original.is_a?(BackingStoreSerializationWriterProxyFactory)
        result = BackingStoreSerializationWriterProxyFactory.new(original)
      end
      enable_backing_store_for_registry(SerializationWriterFactoryRegistry.default_instance,
                                        BackingStoreSerializationWriterProxyFactory)
      result
    end

    # wraps the factory, and every factory registered by default, so models start tracking changes once read
    def self.enable_backing_store_for_parse_node_factory(original)
      result = original
      if original.is_a?(ParseNodeFactoryRegistry)
        enable_backing_store_for_registry(original, BackingStoreParseNodeFactory)
      elsif !original.is_a?(BackingStoreParseNodeFactory)
        result = BackingStoreParseNodeFactory.new(original)
      end
      enable_backing_store_for_registry(ParseNodeFactoryRegistry.default_instance, BackingStoreParseNodeFactory)
      result
    end

    def self.enable_backing_store_for_registry(registry, proxy_class)
      factories = registry.content_type_associated_factories
      factories.each do |content_type, factory|
        next if factory.is_a?(proxy_class) || factory.is_a?(registry.class)

        factories[content_type] = proxy_class.new(factory)
      end
    end
    private_class_method :enable_backing_store_for_registry

    def self.register_default_deserializer(factory_class)
      factory = factory_class.new
      MicrosoftKiotaAbstractions::ParseNodeFactoryRegistry.default_instance.content_type_associated_factories[factory.get_valid_content_type] =
        factory
    end
  end
end
