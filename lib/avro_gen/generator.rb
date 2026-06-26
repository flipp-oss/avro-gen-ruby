# frozen_string_literal: true

require 'erb'
require 'rails/generators'
require 'schema_registry_client'
require 'active_support/core_ext'
require_relative 'configuration'
require_relative 'avro_parser'
require_relative 'schema_field'
require_relative 'schema_class'
require_relative 'schema_validator'

module AvroGen
  # Generator for Schema Classes used for the IDE and consumer/producer interfaces.
  class Generator < Rails::Generators::Base
    # @return [Array<Symbol>]
    SPECIAL_TYPES = %i(record enum).freeze
    # @return [String]
    INITIALIZE_WHITESPACE = "\n#{' ' * 19}".freeze
    # @return [Array<String>]
    IGNORE_DEFAULTS = %w(message_id timestamp).freeze
    # @return [String]
    SCHEMA_CLASS_FILE = 'schema_class.rb'
    # @return [String]
    SCHEMA_RECORD_PATH = File.expand_path('generator/templates/schema_record.rb.tt', __dir__).freeze
    # @return [String]
    SCHEMA_ENUM_PATH = File.expand_path('generator/templates/schema_enum.rb.tt', __dir__).freeze

    source_root File.expand_path('generator/templates', __dir__)

    no_commands do
      # Retrieve the fields from this Avro Schema
      # @param schema [Avro::Schema::NamedSchema]
      # @return [Array<SchemaField>]
      def fields(schema)
        schema.fields.map do |field|
          AvroGen::SchemaField.new(field.name, field.type, [], field.default)
        end
      end

      # Converts AvroGen::SchemaField's to String form for generated YARD docs
      # @param schema_field [AvroGen::SchemaField]
      # @return [String] A string representation of the Type of this SchemaField
      def deimos_field_type(schema_field)
        _field_type(schema_field.type)
      end

      # Generate a Schema Model Class and all of its Nested Records from a
      # schema name and namespace.
      # @param schema_name [String]
      # @param namespace [String]
      # @param key_config [Hash,nil]
      # @return [void]
      def generate_classes(schema_name, namespace, key_config=nil)
        schema_base = _schema_loader(schema_name, namespace)
        schema_base.load_schema
        if key_config&.dig(:schema)
          key_schema_base = _schema_loader(key_config[:schema], namespace)
          key_schema_base.load_schema
          generate_class_from_schema_base(key_schema_base, key_config: nil)
        end
        generate_class_from_schema_base(schema_base, key_config: key_config)
      end

      # Generate classes for an explicit list of schema configs (each a Hash with
      # :schema, :namespace and optional :key_config), then generate every other
      # schema found in the configured path. This is the orchestration entry point
      # used by Deimos (which derives configs from its Kafka topics).
      # @param configs [Array<Hash>] [{ schema:, namespace:, key_config: }]
      # @return [void]
      def generate_from_configs(configs)
        found_schemas = {}
        configs.each do |config|
          schema_name = config[:schema]
          next if schema_name.nil?

          namespace = config[:namespace]
          key_config = config[:key_config] || {}
          key_schema_name = key_config[:schema]

          # don't regenerate if the schema was already found and had a payload key
          next if found_schemas["#{namespace}.#{schema_name}"].present?

          found_schemas["#{namespace}.#{schema_name}"] = key_schema_name
          found_schemas["#{namespace}.#{key_schema_name}"] = nil
          generate_classes(schema_name, namespace, key_config)
        end

        generate_from_path(skip: found_schemas.keys)
      end

      # Generate classes for every schema found in the configured schema path.
      # @param skip [Array<String>] full schema names ("namespace.name") to skip
      # @return [void]
      def generate_from_path(skip: [])
        path = AvroGen.config.schema_path
        schema_store = SchemaRegistry::AvroSchemaStore.new(path: path)
        schema_store.load_schemas!
        schema_store.schemas.values.sort_by { |s| "#{s.namespace}#{s.name}" }.each do |schema|
          name = "#{schema.namespace}.#{schema.name}"
          next if skip.include?(name)

          generate_classes(schema.name, schema.namespace, nil)
        end
      end

      # @param schema [Avro::Schema::NamedSchema]
      # @return [Array<Avro::Schema::NamedSchema]
      def child_schemas(schema)
        if schema.respond_to?(:fields)
          schema.fields.map(&:type)
        elsif schema.respond_to?(:values)
          [schema.values]
        elsif schema.respond_to?(:items)
          [schema.items]
        elsif schema.respond_to?(:schemas)
          schema.schemas.reject { |s| s.instance_of?(Avro::Schema::PrimitiveSchema) }
        else
          []
        end
      end

      # @param schemas [Array<Avro::Schema::NamedSchema>]
      # @return [Array<Avro::Schema::NamedSchema>]
      def collect_all_schemas(schemas)
        schemas.dup.each do |schema|
          next if @discovered_schemas.include?(schema)

          @discovered_schemas << schema
          schemas.concat(collect_all_schemas(child_schemas(schema)))
        end

        schemas.select { |s| s.respond_to?(:name) }.uniq
      end

      # @param schema_base [AvroGen::SchemaValidator]
      # @param key_config [Hash,nil]
      # @return [void]
      def generate_class_from_schema_base(schema_base, key_config: nil)
        @discovered_schemas = Set.new
        @sub_schema_templates = []
        schemas = collect_all_schemas(schema_base.schema_store.schemas.values)

        main_schema = schemas.find { |s| s.name == schema_base.schema }
        sub_schemas = schemas.reject { |s| s.name == schema_base.schema }.sort_by(&:name)
        if AvroGen.config.nest_child_schemas
          @sub_schema_templates = sub_schemas.map do |schema|
            _generate_class_template_from_schema(schema, nil)
          end
          write_file(main_schema, key_config)
        else
          write_file(main_schema, key_config)
          sub_schemas.each do |schema|
            write_file(schema, nil)
          end
        end
      end

      # @param schema [Avro::Schema::NamedSchema]
      # @param key_config [Hash,nil]
      # @return [void]
      def write_file(schema, key_config)
        class_template = _generate_class_template_from_schema(schema, key_config)
        @modules = AvroGen::SchemaClass.modules_for(schema.namespace)
        @main_class_definition = class_template

        file_prefix = schema.name.underscore.singularize
        if AvroGen.config.use_full_namespace
          # Use entire namespace for folders
          # but don't add directories that are already in the path
          directories = @modules.map(&:underscore).select do |m|
            AvroGen.config.generated_class_path.exclude?(m)
          end

          file_prefix = "#{directories.join('/')}/#{file_prefix}"
        end

        filename = "#{AvroGen.config.generated_class_path}/#{file_prefix}.rb"
        template(SCHEMA_CLASS_FILE, filename, force: true)
      end

      # Format a given field into its appropriate to_h representation.
      # @param field[AvroGen::SchemaField]
      # @return [String]
      def field_as_json(field)
        res = "'#{field.name}' => @#{field.name}"
        field_base_type = _schema_base_class(field.type).type_sym

        if %i(record enum).include?(field_base_type)
          res += case field.type.type_sym
                 when :array
                   '.map { |v| v&.as_json }'
                 when :map
                   '.transform_values { |v| v&.as_json }'
                 else
                   '&.as_json'
                 end
        end

        res + (field.name == @fields.last.name ? '' : ',')
      end
    end

    desc 'Generate schema classes from the configured schema path.'
    # @return [void]
    def generate
      Rails.logger&.info("Generating schema classes to #{AvroGen.config.generated_class_path}")
      generate_from_path
    end

  private

    # @param schema_name [String]
    # @param namespace [String]
    # @return [AvroGen::SchemaValidator]
    def _schema_loader(schema_name, namespace)
      AvroGen::SchemaValidator.new(schema: schema_name, namespace: namespace)
    end

    # @param schema[Avro::Schema::NamedSchema]
    # @param key_config[Hash,nil]
    # @return [String]
    def _generate_class_template_from_schema(schema, key_config)
      _set_instance_variables(schema, key_config)

      temp = schema.is_a?(Avro::Schema::RecordSchema) ? _record_class_template : _enum_class_template
      res = ERB.new(temp, trim_mode: '-')
      res.result(binding)
    end

    # @param schema[Avro::Schema::NamedSchema]
    # @param key_config [Hash,nil]
    def _set_instance_variables(schema, key_config)
      schema_is_record = schema.is_a?(Avro::Schema::RecordSchema)
      @current_schema = schema
      return unless schema_is_record

      @fields = fields(schema)
      key_schema = nil
      if key_config&.dig(:schema)
        key_schema_base = _schema_loader(key_config[:schema], schema.namespace)
        key_schema_base.load_schema
        key_schema = key_schema_base.schema_store.schemas.values.first
        @fields << AvroGen::SchemaField.new('payload_key', key_schema, [], nil)
      end
      @initialization_definition = _initialization_definition
      @field_assignments = _field_assignments
      @tombstone_assignment = _tombstone_assignment(key_config, key_schema)
    end

    def _tombstone_assignment(key_config, key_schema)
      return nil unless key_config

      if key_config[:plain]
        'record.tombstone_key = key'
      elsif key_config[:field]
        "record.tombstone_key = key\n      record.#{key_config[:field]} = key"
      elsif key_schema
        field_base_type = _field_type(key_schema)
        "record.tombstone_key = #{field_base_type}.initialize_from_value(key)\n      record.payload_key = key"
      else
        ''
      end
    end

    # Defines the initialization method for Schema Records with one keyword argument per line
    # @return [String] A string which defines the method signature for the initialize method
    def _initialization_definition
      arguments = @fields.map do |schema_field|
        arg = "#{schema_field.name}:"
        arg += _field_default(schema_field)
        arg.strip
      end

      result = "def initialize(_from_message: false, #{arguments.first}"
      arguments[1..].each_with_index do |arg, _i|
        result += ",#{INITIALIZE_WHITESPACE}#{arg}"
      end
      "#{result})"
    end

    # @param field [SchemaField]
    # @return [String]
    def _field_default(field)
      default = field.default
      return ' nil' if default == :no_default || default.nil? || IGNORE_DEFAULTS.include?(field.name)

      type_sym = field.type.type_sym
      if type_sym == :union
        type_sym = field.type.schemas.find { |s| s.type_sym != :null }&.type_sym
      end
      case type_sym
      when :string, :enum
        " \"#{default}\""
      when :record
        schema_name = AvroGen::AvroParser.schema_classname(field.type)
        class_instance = AvroGen::SchemaClass.instance(field.default, schema_name)
        " #{class_instance.to_h}"
      else
        " #{default}"
      end
    end

    # Overrides default attr accessor methods
    # @return [Array<String>]
    def _field_assignments
      result = []
      @fields.each do |field|
        field_type = field.type.type_sym # Record, Union, Enum, Array or Map
        schema_base_type = _schema_base_class(field.type)
        field_base_type = _field_type(schema_base_type)
        method_argument = %i(array map).include?(field_type) ? 'values' : 'value'
        is_schema_class = %i(record enum).include?(schema_base_type.type_sym)

        field_initialization = method_argument

        if _is_complex_union?(field)
          field_initialization = "initialize_#{field.name}_type(value, from_message: self._from_message)"
        elsif is_schema_class
          field_initialization = "#{field_base_type}.initialize_from_value(value, from_message: self._from_message)"
        end

        result << {
          field: field,
          field_type: field_type,
          is_schema_class: is_schema_class,
          method_argument: method_argument,
          deimos_type: deimos_field_type(field),
          field_initialization: field_initialization,
          is_complex_union: _is_complex_union?(field)
        }
      end

      result
    end

    # Helper method to detect if a field is a complex union type with multiple record schemas
    # @param field [AvroGen::SchemaField]
    # @return [Boolean]
    def _is_complex_union?(field)
      return false unless field.type.type_sym == :union

      non_null_schemas = field.type.schemas.reject { |s| s.type_sym == :null }

      record_schemas = non_null_schemas.select { |s| s.type_sym == :record }
      record_schemas.length > 1
    end

    # Converts Avro::Schema::NamedSchema's to String form for generated YARD docs.
    # @param avro_schema [Avro::Schema::NamedSchema]
    # @return [String] A string representation of the Type of this SchemaField
    def _field_type(avro_schema)
      AvroGen::AvroParser.field_type(avro_schema)
    end

    # Returns the base class for this schema. Decodes Arrays, Maps and Unions
    # @param avro_schema [Avro::Schema::NamedSchema]
    # @return [Avro::Schema::NamedSchema]
    def _schema_base_class(avro_schema)
      AvroGen::AvroParser.schema_base_class(avro_schema)
    end

    # An ERB template for schema record classes
    # @return [String]
    def _record_class_template
      File.read(SCHEMA_RECORD_PATH).strip
    end

    # An ERB template for schema enum classes
    # @return [String]
    def _enum_class_template
      File.read(SCHEMA_ENUM_PATH).strip
    end
  end
end
