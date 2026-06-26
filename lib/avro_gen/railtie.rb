# frozen_string_literal: true

require 'rails/railtie'

module AvroGen
  # Exposes the avro:* rake tasks to a host Rails application.
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path('../tasks/avro.rake', __dir__)
    end
  end
end
