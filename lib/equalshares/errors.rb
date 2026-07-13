# frozen_string_literal: true

module Equalshares
  class Error < StandardError; end

  # Raised when a pabulib (.pb) file cannot be parsed.
  class ParseError < Error; end

  # Raised for invalid parameters or unresolvable ties during computation.
  class ComputeError < Error; end
end
