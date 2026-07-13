# frozen_string_literal: true

module Equalshares
  # Computation parameters. Mirrors the `equalSharesParams` object from js/main.js
  # and the allowed values wired up in js/interface/formHandler.js.
  class Params
    TIE_BREAKING_METHODS = %w[maxVotes minCost maxCost].freeze
    COMPLETIONS = %w[none utilitarian add1 add1e add1u add1eu].freeze
    ADD1_OPTIONS = %w[exhaustive integral].freeze
    COMPARISONS = %w[none satisfaction exclusionRatio].freeze
    ACCURACIES = %w[floats fractions].freeze
    SATISFACTIONS = Satisfaction::NAMES

    attr_reader :tie_breaking, :completion, :add1_options, :comparison, :accuracy, :increment, :satisfaction

    # Defaults match js/main.js:6-13. `satisfaction` selects the MES satisfaction
    # measure (pabutools parity); "cost" is the equalshares.net default.
    def initialize(tie_breaking: [], completion: "add1u", add1_options: %w[exhaustive integral],
                   comparison: "none", accuracy: "floats", increment: 1, satisfaction: "cost")
      @tie_breaking = Array(tie_breaking)
      @completion = completion
      @add1_options = Array(add1_options)
      @comparison = comparison
      @accuracy = accuracy
      @increment = increment
      @satisfaction = satisfaction
      validate!
    end

    def add1_option?(name)
      @add1_options.include?(name)
    end

    private

    def validate!
      @tie_breaking.each do |m|
        # A tie-breaking method is a known keyword, an explicit candidate-order list
        # (Array), or a total order ({ lexico: [...] }).
        next if m.is_a?(Array) || m.is_a?(Hash) || TIE_BREAKING_METHODS.include?(m)

        raise ComputeError, "Unknown tie-breaking method: #{m}"
      end
      validate_inclusion(:completion, @completion, COMPLETIONS)
      validate_inclusion(:comparison, @comparison, COMPARISONS)
      validate_inclusion(:accuracy, @accuracy, ACCURACIES)
      validate_inclusion(:satisfaction, @satisfaction, SATISFACTIONS)
      @add1_options.each { |o| validate_inclusion(:add1_options, o, ADD1_OPTIONS) }
      return if @increment.is_a?(Integer) && @increment.positive?

      raise ComputeError,
            "increment must be a positive integer"
    end

    def validate_inclusion(field, value, allowed)
      return if allowed.include?(value)

      raise ComputeError, "Invalid #{field}: #{value.inspect} (allowed: #{allowed.join(', ')})"
    end
  end
end
