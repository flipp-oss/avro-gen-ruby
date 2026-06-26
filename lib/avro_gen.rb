# frozen_string_literal: true

require 'avro_gen/version'
require 'avro_gen/errors'
require 'avro_gen/configuration'
require 'avro_gen/schema_field'
require 'avro_gen/avro_parser'
require 'avro_gen/schema_validator'
require 'avro_gen/schema_class'
require 'avro_gen/schema_class/base'
require 'avro_gen/schema_class/enum'
require 'avro_gen/schema_class/record'

require 'avro_gen/railtie' if defined?(Rails::Railtie)

# Top-level namespace for the Avro schema-class generator.
module AvroGen
end
