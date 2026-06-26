# frozen_string_literal: true

require 'fileutils'

# Serializes a hash of { filename => contents } into a stable snapshot string.
class MultiFileSerializer
  def process_string(str)
    # Ruby 3.4 changes how hashes are printed
    if Gem::Version.new(RUBY_VERSION) > Gem::Version.new('3.4.0')
      str.gsub(/{"(.*)" => /, '{"\1"=>')
    else
      str
    end
  end

  def dump(value)
    value.keys.sort.map { |k| "#{k}:\n#{process_string(value[k])}\n" }.join("\n")
  end
end

RSpec.describe AvroGen::Generator do
  let(:schema_class_path) { 'spec/app/lib/schema_classes' }
  let(:files) { Dir["#{schema_class_path}/**/*.rb"].to_h { |f| [f, File.read(f)] } }

  # A schema with a field-based key, plus every other schema in the path
  # generated as a plain class. This exercises records, enums, nested records,
  # complex types (arrays/maps/unions) and circular references all at once.
  let(:configs) do
    [{ schema: 'Generated', namespace: 'com.my-namespace', key_config: { field: :a_string } }]
  end

  before(:each) do
    AvroGen.config.schema_path = 'spec/schemas'
    AvroGen.config.generated_class_path = schema_class_path
  end

  after(:each) do
    FileUtils.rm_rf('spec/app')
  end

  it 'generates the correct classes with child schemas nested' do
    AvroGen.config.nest_child_schemas = true
    described_class.new.generate_from_configs(configs)
    expect(files).to match_snapshot('consumers', snapshot_serializer: MultiFileSerializer)
  end

  it 'generates the correct classes with child schemas in their own files' do
    AvroGen.config.nest_child_schemas = false
    described_class.new.generate_from_configs(configs)
    expect(files).to match_snapshot('consumers-no-nest', snapshot_serializer: MultiFileSerializer)
  end

  it 'generates folders matching the full namespace' do
    AvroGen.config.use_full_namespace = true
    described_class.new.generate_from_configs(configs)
    expect(files).to match_snapshot('namespace_folders', snapshot_serializer: MultiFileSerializer)
  end

  it 'generates modules according to the namespace map' do
    AvroGen.config.use_full_namespace = true
    AvroGen.config.schema_namespace_map = {
      'com' => 'Schemas',
      'com.my-namespace.my-suborg' => %w(Schemas MyNamespace)
    }
    described_class.new.generate_from_configs(configs)
    expect(files).to match_snapshot('namespace_map', snapshot_serializer: MultiFileSerializer)
  end

  # The snapshots above cover the full output, but these focused cases make it
  # explicit that each notable Avro construct generates correctly (these mirror
  # the per-schema scenarios that previously lived in Deimos).
  describe 'specific Avro constructs' do
    before(:each) do
      AvroGen.config.nest_child_schemas = true
      described_class.new.generate_from_path
    end

    {
      'records with complex types (arrays, maps, nested records and enums)' => 'my_schema_with_complex_type',
      'records with a circular reference' => 'my_schema_with_circular_reference',
      'records with union types' => 'my_schema_with_union_type',
      'records with nested child records' => 'my_nested_schema',
      'records with date/time logical types' => 'my_schema_with_date_time',
      'records with boolean fields' => 'my_schema_with_boolean'
    }.each do |description, file|
      it "generates #{description}" do
        expect(files.slice("#{schema_class_path}/#{file}.rb")).
          to match_snapshot(file, snapshot_serializer: MultiFileSerializer)
      end
    end
  end
end
