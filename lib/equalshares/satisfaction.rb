# frozen_string_literal: true

module Equalshares
  # Additive satisfaction measures for approval ballots, matching pabutools.
  #
  # For the Method of Equal Shares, only the per-approver marginal utility u_i(c)
  # of a project matters, and for these measures it is uniform across all approvers
  # of c (it depends on c, not on i). This lets the fixed-budget loop stay unchanged
  # in its payment mechanics (each project still has to raise its full cost, split as
  # equally as possible) while the *selection* criterion becomes u(c) / maxPayment.
  #
  #   Cost_Sat        u(c) = cost(c)                 (equalshares.net default)
  #   Cardinality_Sat u(c) = 1
  #
  # Both are verified to match pabutools exactly (Cost_Sat and Cardinality_Sat).
  # Each strategy returns the per-approver utility in the same numeric family as the
  # cost passed in (Rational for exact mode, Float for float mode), so downstream
  # arithmetic keeps its accuracy.
  module Satisfaction
    module_function

    NAMES = %w[cost cardinality effort].freeze

    def for(name)
      case name
      when "cost" then COST
      when "cardinality" then CARDINALITY
      when "effort" then EFFORT
      else
        raise ComputeError, "Unknown satisfaction measure: #{name} (allowed: #{NAMES.join(', ')})"
      end
    end

    # Each measure is a callable per_voter(cost_c, num_approvers) -> Numeric.
    COST = ->(cost_c, _n) { cost_c }
    CARDINALITY = ->(_cost_c, _n) { 1 }
    EFFORT = ->(cost_c, n) { cost_c / n }
  end
end
