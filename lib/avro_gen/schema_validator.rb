# frozen_string_literal: true

require 'avro'
require 'schema_registry_client'
require_relative 'schema_field'

module AvroGen
  # Loads an Avro schema from the configured schema path and exposes its fields.
  # Used at runtime by generated Record classes (for #schema_fields) and as the
  # schema loader for the generator.
  class SchemaValidator
    # @return [String]
    attr_reader :schema
    # @return [String]
    attr_reader :namespace

    @stores = {}

    class << self
      # A schema store is an in-memory cache of parsed Avro schemas. Reuse one per
      # path so repeated runtime lookups (e.g. Record#schema_fields across many
      # records) don't re-read and re-parse the .avsc files each time.
      # @param path [String]
      # @return [SchemaRegistry::AvroSchemaStore]
      def store_for(path)
        (@stores ||= {})[path] ||= SchemaRegistry::AvroSchemaStore.new(path: path)
      end

      # Drop cached stores; call when the schemas on disk may have changed.
      # @return [void]
      def clear_store_cache!
        @stores = {}
      end
    end

    # @param schema [String]
    # @param namespace [String]
    # @param path [String] location of .avsc files; defaults to the configured schema_path
    # @param store [SchemaRegistry::AvroSchemaStore] an existing store to reuse; when
    #   omitted a fresh, isolated store is created (the generator relies on this).
    def initialize(schema:, namespace:, path: nil, store: nil)
      @schema = schema
      @namespace = namespace
      @path = path || AvroGen.config.schema_path
      @schema_store = store
    end

    # @return [SchemaRegistry::AvroSchemaStore]
    def schema_store
      @schema_store ||= SchemaRegistry::AvroSchemaStore.new(path: @path)
    end

    # Forcefully loads the schema into memory.
    # @return [Avro::Schema]
    def load_schema
      avro_schema
    end

    # @return [Avro::Schema::NamedSchema]
    def avro_schema(schema=nil)
      schema ||= @schema
      schema_store.find("#{@namespace}.#{schema}")
    end

    # @return [Array<AvroGen::SchemaField>]
    def schema_fields
      avro_schema.fields.map do |field|
        enum_values = field.type.type == 'enum' ? field.type.symbols : []
        AvroGen::SchemaField.new(field.name, field.type, enum_values, field.default)
      end
    end

    # @return [void]
    def validate(payload, schema: nil)
      Avro::SchemaValidator.validate!(avro_schema(schema), payload,
                                      recursive: true,
                                      fail_on_extra_fields: true)
    end
  end
end
