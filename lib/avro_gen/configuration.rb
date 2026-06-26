# frozen_string_literal: true

module AvroGen
  # Configuration for schema class generation.
  class Configuration
    # Local path to look for Avro schemas (.avsc files) in.
    # @return [String]
    attr_accessor :schema_path

    # Local path for schema classes to be generated in.
    # @return [String]
    attr_accessor :generated_class_path

    # Set to false to generate child schemas as their own files.
    # @return [Boolean]
    attr_accessor :nest_child_schemas

    # Set to true to generate folders matching the last part of the schema namespace.
    # @return [Boolean]
    attr_accessor :use_full_namespace

    # Use this option to reduce nesting when using use_full_namespace.
    # For example: { 'com.mycompany.suborg' => 'SchemaClasses' }
    # would replace a prefix matching the given key with the module name SchemaClasses.
    # @return [Hash]
    attr_accessor :schema_namespace_map

    # The top-level module that generated classes are nested under.
    # @return [String]
    attr_accessor :root_module

    def initialize
      reset!
    end

    # Restore all settings to their defaults.
    # @return [void]
    def reset!
      @schema_path = nil
      @generated_class_path = 'app/lib/schema_classes'
      @nest_child_schemas = true
      @use_full_namespace = false
      @schema_namespace_map = {}
      @root_module = 'Schemas'
    end
  end

  class << self
    # @return [AvroGen::Configuration]
    def config
      @config ||= Configuration.new
    end

    # @yieldparam [AvroGen::Configuration]
    # @return [void]
    def configure
      yield config if block_given?
    end
  end
end
