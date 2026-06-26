# frozen_string_literal: true

require 'active_support/core_ext/string'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'

module AvroGen
  # Helpers used by the generator and by consumer/producer interfaces to
  # locate and instantiate generated schema classes.
  module SchemaClass
    class << self
      # @param namespace [String]
      # @return [Array<String>]
      def modules_for(namespace)
        modules = [AvroGen.config.root_module]
        namespace_override = nil
        module_namespace = namespace

        if AvroGen.config.use_full_namespace
          if AvroGen.config.schema_namespace_map.present?
            namespace_keys = AvroGen.config.schema_namespace_map.keys.sort_by { |k| -k.length }
            namespace_override = namespace_keys.find { |k| module_namespace.include?(k) }
          end

          if namespace_override.present?
            # override default module
            modules = Array(AvroGen.config.schema_namespace_map[namespace_override])
            module_namespace = module_namespace.gsub(/#{namespace_override}\.?/, '')
          end

          namespace_folders = module_namespace.split('.').map { |f| f.underscore.camelize }
          modules.concat(namespace_folders) if namespace_folders.any?
        end

        modules
      end

      # Converts a raw payload into an instance of the Schema Class
      # @param payload [Hash, AvroGen::SchemaClass::Base]
      # @param schema [String]
      # @param namespace [String]
      # @return [AvroGen::SchemaClass::Record]
      def instance(payload, schema, namespace='')
        return payload if payload.is_a?(AvroGen::SchemaClass::Base)

        klass = klass(schema, namespace)
        return payload if klass.nil? || payload.nil?

        klass.new_from_message(**payload.symbolize_keys)
      end

      # Determine and return the SchemaClass with the provided schema and namespace
      # @param schema [String]
      # @param namespace [String]
      # @return [Class, nil]
      def klass(schema, namespace)
        constants = modules_for(namespace) + [schema.underscore.camelize.singularize]
        constants.join('::').safe_constantize
      end
    end
  end
end
