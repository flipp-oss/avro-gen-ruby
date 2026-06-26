# frozen_string_literal: true

module AvroGen
  # Represents a field in the schema.
  class SchemaField
    # @return [String]
    attr_accessor :name
    # @return [Object]
    attr_accessor :type
    # @return [Array<String>]
    attr_accessor :enum_values
    # @return [Object]
    attr_accessor :default

    # @param name [String]
    # @param type [Object]
    # @param enum_values [Array<String>]
    # @param default [Object]
    def initialize(name, type, enum_values=[], default=:no_default)
      @name = name
      @type = type
      @enum_values = enum_values
      @default = default
    end
  end
end
