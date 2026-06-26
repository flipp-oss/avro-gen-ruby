# frozen_string_literal: true

require 'avro_gen'
require 'avro_gen/generator'
require 'avro_gen/upgrader'
require 'rspec/snapshot'

# Load the committed generated schema classes (used by the behaviour specs).
Dir['./spec/schemas/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  config.snapshot_dir = 'spec/snapshots'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    AvroGen.config.reset!
    AvroGen.config.schema_path = 'spec/schemas'
    AvroGen::SchemaValidator.clear_store_cache!
  end
end
