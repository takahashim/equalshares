# frozen_string_literal: true

module Equalshares
  # Tie-breaking facade. Composes the TieBreaker strategies named in params.tie_breaking
  # to either resolve a single tie (break_ties) or build a total order (total_order).
  module Tie
    module_function

    # Resolve a tie among `choices` by applying each tie-breaking strategy in priority
    # order, narrowing the set. Returns the surviving candidates (callers treat more
    # than one as an unresolved tie).
    def break_ties(_project_ids, cost, approvers, params, choices)
      ctx = TieBreaker::Context.new(cost, approvers)
      remaining = params.tie_breaking.reduce(choices.dup) do |current, method|
        TieBreaker.for(method).filter(current, ctx)
      end

      raise ComputeError, "Tie-breaking failed in a way that should not happen: #{choices}" if remaining.empty?

      remaining
    end

    # Resolve a tie down to a single winner, raising if the tie-breaking rules leave
    # more than one candidate. Used by the sequential rules.
    def resolve_one(project_ids, cost, approvers, params, choices)
      resolved = break_ties(project_ids, cost, approvers, params, choices)
      if resolved.length > 1
        raise ComputeError,
              "Tie-breaking failed: tie between projects #{resolved.join(', ')} could not be resolved. " \
              "Another tie-breaking needs to be added."
      end
      resolved[0]
    end

    # A total order of all projects induced by params.tie_breaking, used by rules that
    # need a full ordering (e.g. greedy welfare). Projects are sorted by each strategy's
    # sort key in priority order, falling back to their original (JS Object.keys) order.
    def total_order(project_ids, cost, approvers, params)
      ctx = TieBreaker::Context.new(cost, approvers)
      strategies = params.tie_breaking.map { |method| TieBreaker.for(method) }
      base_index = project_ids.each_with_index.to_h

      project_ids.sort_by do |c|
        strategies.map { |strategy| strategy.sort_key(c, ctx) } + [base_index[c]]
      end
    end
  end
end
