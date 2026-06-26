# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'avro_gen/version'

Gem::Specification.new do |spec|
  spec.name          = 'avro-gen-ruby'
  spec.version       = AvroGen::VERSION
  spec.authors       = ['Daniel Orner']
  spec.email         = ['daniel.orner@flipp.com']
  spec.summary       = 'Generate Ruby schema classes from Avro schemas.'
  spec.homepage      = 'https://github.com/flipp-oss/avro-gen-ruby'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency('activesupport', '>= 6.0')
  spec.add_dependency('avro', '~> 1.9')
  spec.add_dependency('railties', '>= 6.0')
  spec.add_dependency('schema_registry_client')

  spec.add_development_dependency('rake', '~> 13')
  spec.add_development_dependency('rspec', '~> 3')
  spec.add_development_dependency('rspec-snapshot', '~> 2.0')
  spec.add_development_dependency('rubocop', '~> 1.0')
  spec.add_development_dependency('rubocop-rspec', '~> 3.0')

  spec.metadata['rubygems_mfa_required'] = 'true'
end
