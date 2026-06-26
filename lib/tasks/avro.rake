# frozen_string_literal: true

namespace :avro do
  desc 'Generate Ruby schema classes from Avro schemas'
  task generate: :environment do
    require 'avro_gen/generator'
    Rails.logger&.info('Running avro:generate')
    AvroGen::Generator.new.generate_from_path
  end

  desc 'Rewrite generated schema classes to use AvroGen instead of Deimos constants'
  task upgrade: :environment do
    require 'avro_gen/upgrader'
    changed = AvroGen::Upgrader.run
    puts "Upgraded #{changed.size} file(s):"
    changed.each { |f| puts "  #{f}" }
  end
end
