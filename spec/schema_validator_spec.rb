# frozen_string_literal: true

RSpec.describe AvroGen::SchemaValidator do
  describe '.store_for' do
    it 'reuses a single store per path' do
      store = described_class.store_for('spec/schemas')
      expect(described_class.store_for('spec/schemas')).to be(store)
    end

    it 'uses a different store for a different path' do
      expect(described_class.store_for('spec/schemas')).
        not_to be(described_class.store_for('other/path'))
    end

    it 'clears the cache on demand' do
      store = described_class.store_for('spec/schemas')
      described_class.clear_store_cache!
      expect(described_class.store_for('spec/schemas')).not_to be(store)
    end
  end

  describe 'Record#validator' do
    it 'shares one schema store across record instances instead of re-parsing' do
      store_one = Schemas::MyNamespace::MySchema.new.validator.schema_store
      store_two = Schemas::MyNamespace::MyNestedSchema.new.validator.schema_store
      expect(store_one).to be(store_two)
      expect(store_one).to be(described_class.store_for(AvroGen.config.schema_path))
    end

    it 'still resolves the schema fields' do
      expect(Schemas::MyNamespace::MySchema.new.schema_fields).to include('test_id', 'some_int')
    end
  end

  describe 'an explicitly provided store' do
    it 'is used instead of creating a new one' do
      store = described_class.store_for('spec/schemas')
      validator = described_class.new(schema: 'MySchema', namespace: 'com.my-namespace', store: store)
      expect(validator.schema_store).to be(store)
    end
  end
end
