# avro-gen-ruby

Generate Ruby schema classes / models from Avro schemas.

`avro-gen-ruby` (namespace `AvroGen`) takes a directory of Avro `.avsc` schema files
and generates plain-Ruby classes for each record and enum, giving you typed,
IDE-friendly objects to work with instead of raw hashes. It was extracted from
[deimos-ruby](https://github.com/flipp-oss/deimos), which now depends on it.

## Installation

```ruby
gem 'avro-gen-ruby'
```

## Configuration

```ruby
AvroGen.configure do |config|
  config.schema_path = 'avro/schemas'
  config.generated_class_path = 'app/lib/schema_classes'
  config.nest_child_schemas = true
  config.use_full_namespace = false
  config.schema_namespace_map = {}
  config.root_module = 'Schemas'
end
```

| Setting | Default | Description |
|---------|---------|-------------|
| `schema_path` | `nil` | Local path to the directory containing your Avro `.avsc` schema files. Required for generation. |
| `generated_class_path` | `app/lib/schema_classes` | Local path that generated schema classes are written to. |
| `nest_child_schemas` | `true` | When `true`, subschemas (nested records/enums) are nested inside the generated class for the parent schema. When `false`, each subschema is generated as its own file. |
| `use_full_namespace` | `false` | When `true`, generate nested folders/modules matching the full Avro namespace (e.g. `com.my-org.Foo` → `Schemas::Com::MyOrg::Foo`). When `false`, all classes are generated directly under the root module. |
| `schema_namespace_map` | `{}` | A map of namespace prefixes to base module name(s), used to reduce nesting when `use_full_namespace` is `true`. Example: `{ 'com.mycompany.suborg' => ['SchemaClasses'] }` generates classes under `SchemaClasses::` instead of `Schemas::Com::Mycompany::Suborg::`. Has no effect unless `use_full_namespace` is `true`. |
| `root_module` | `'Schemas'` | The top-level module that generated classes are nested under. |

## Usage

Generate classes for every schema in `schema_path`:

```bash
rake avro:generate
```

Generated classes inherit from `AvroGen::SchemaClass::Record` / `AvroGen::SchemaClass::Enum`
and are namespaced under the configured `root_module` (default `Schemas`).

### Migrating from Deimos

If you previously generated classes with Deimos, they reference `Deimos::SchemaClass::*`.
Those still load (Deimos maps them to the AvroGen equivalents with a deprecation warning),
but you can rewrite them in place:

```bash
rake avro:upgrade
```

## License

MIT
