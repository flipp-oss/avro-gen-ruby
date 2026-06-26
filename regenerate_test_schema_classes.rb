#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the committed runtime schema-class fixtures under spec/schemas/my_namespace.
# These are loaded by the behaviour specs (e.g. spec/my_schema_spec.rb).
require 'avro_gen'
require 'avro_gen/generator'

AvroGen.configure do |config|
  config.schema_path = 'spec/schemas'
  config.generated_class_path = 'spec/schemas'
  config.nest_child_schemas = true
  config.use_full_namespace = true
  config.schema_namespace_map = {
    'com' => 'Schemas',
    'com.my-namespace.my-suborg' => %w(Schemas MyNamespace)
  }
end

# Key configs mirror the Kafka topic configs Deimos used to generate these fixtures,
# so that keyed records get their tombstone/payload_key helpers.
ns = 'com.my-namespace'
configs = [
  { schema: 'Generated', namespace: ns, key_config: { field: :a_string } },
  { schema: 'MyNestedSchema', namespace: ns, key_config: { field: :test_id } },
  { schema: 'MySchema', namespace: ns, key_config: { schema: 'MySchema_key' } },
  { schema: 'MySchemaWithComplexTypes', namespace: ns, key_config: { field: :test_id } },
  { schema: 'MySchemaWithCircularReference', namespace: ns, key_config: { none: true } },
  { schema: 'MyLongNamespaceSchema', namespace: "#{ns}.my-suborg", key_config: { field: :test_id } }
]

AvroGen::Generator.new.generate_from_configs(configs)
