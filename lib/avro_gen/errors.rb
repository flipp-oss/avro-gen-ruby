# frozen_string_literal: true

module AvroGen
  # Raised when a subclass fails to implement a required method.
  class MissingImplementationError < StandardError; end
end
