# frozen_string_literal: true

require 'avro'
require 'active_support/core_ext/string'

module AvroGen
  # Helper methods for interpreting Avro schema objects when generating classes.
  module AvroParser
    class << self
      # @param schema [Avro::Schema::NamedSchema] A named schema
      # @return [String]
      def schema_classname(schema)
        schema.name.underscore.camelize.singularize
      end

      # Converts Avro::Schema::NamedSchema's to String form for generated YARD docs.
      # Recursively handles the typing for Arrays, Maps and Unions.
      # @param avro_schema [Avro::Schema::NamedSchema]
      # @return [String] A string representation of the Type of this SchemaField
      def field_type(avro_schema)
        case avro_schema.type_sym
        when :string, :boolean
          avro_schema.type_sym.to_s.titleize
        when :int, :long
          'Integer'
        when :float, :double
          'Float'
        when :record, :enum
          schema_classname(avro_schema)
        when :array
          arr_t = field_type(Deimos::SchemaField.new('n/a', avro_schema.items).type)
          "Array<#{arr_t}>"
        when :map
          map_t = field_type(Deimos::SchemaField.new('n/a', avro_schema.values).type)
          "Hash<String, #{map_t}>"
        when :union
          types = avro_schema.schemas.map do |t|
            field_type(Deimos::SchemaField.new('n/a', t).type)
          end
          types.join(', ')
        when :null
          'nil'
        end
      end

      # Returns the base type of this schema. Decodes Arrays, Maps and Unions
      # @param schema [Avro::Schema::NamedSchema]
      # @return [Avro::Schema::NamedSchema]
      def schema_base_class(schema)
        case schema.type_sym
        when :array
          schema_base_class(schema.items)
        when :map
          schema_base_class(schema.values)
        when :union
          schema.schemas.map(&method(:schema_base_class)).
            reject { |s| s.type_sym == :null }.first
        else
          schema
        end
      end
    end
  end
end
