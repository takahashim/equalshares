# frozen_string_literal: true

module Equalshares
  # A numeric view of an instance for a given accuracy. It exposes the voters,
  # projects and supporters together with the per-project cost, the budget and the
  # per-voter utilities, all converted to the right numeric type (exact Rational for
  # "fractions", Float for "floats"). This centralises the setup that every rule
  # previously repeated, and provides the float-based statistics used for reporting.
  class Election
    attr_reader :instance, :params

    def initialize(instance, params = Params.new)
      @instance = instance
      @params = params
      @exact = params.accuracy == "fractions"
      @costs = instance.project_ids.to_h { |c| [c, numeric(instance.projects[c]["cost"])] }
      @float_costs = instance.project_ids.to_h { |c| [c, Float(instance.projects[c]["cost"])] }
    end

    def voter_ids
      instance.voter_ids
    end

    def project_ids
      instance.project_ids
    end

    def approvers
      instance.approvers
    end

    def supporters(project_id)
      instance.approvers[project_id]
    end

    def exact?
      @exact
    end

    # Per-project cost in the accuracy's numeric type, as a Hash{project_id => Numeric}.
    attr_reader :costs

    # Per-project cost as floats, as a Hash{project_id => Float} (for statistics and the
    # cost/comparison bookkeeping that the equalshares.net tool always does in floats).
    attr_reader :float_costs

    def budget
      @budget ||= numeric(instance.budget)
    end

    def float_budget
      @float_budget ||= Float(instance.budget)
    end

    # Per-project voter utilities for cardinal/ordinal ballots: { voter_id => Numeric }.
    def utilities(project_id)
      (instance.scores[project_id] || {}).transform_values { |score| numeric(score) }
    end

    def statistics(winners)
      Statistics.gather(voter_ids, @float_costs, instance.approvers, winners)
    end

    # Convert a cost/budget/score string to the accuracy's numeric type.
    def numeric(value)
      @exact ? self.class.rational_of(value) : Float(value)
    end

    # Exact rational from a cost/budget string, matching fraction.js's decimal handling
    # ("5000" -> 5000, "5000.5" -> 10001/2).
    def self.rational_of(value)
      Rational(value.to_s)
    rescue ArgumentError
      Float(value).to_r
    end
  end
end
