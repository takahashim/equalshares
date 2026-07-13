# frozen_string_literal: true

module Equalshares
  # Tie-breaking. Faithful port of breakTies() in js/methodOfEqualSharesWorker.js.
  module Tie
    module_function

    # Resolve a tie among `choices` using the ordered methods in params.tie_breaking.
    # Each method is one of:
    #   "maxVotes" / "minCost" / "maxCost"       — keyword criteria
    #   Array                                    — JS-faithful explicit list: keep the
    #                                              first *choice* that appears in the list
    #   { lexico: [ids...] }                     — total order (pabutools-style): keep the
    #                                              choice that comes *first in the list*
    def break_ties(_project_ids, cost, approvers, params, choices)
      remaining = choices.dup

      params.tie_breaking.each do |method|
        case method
        when "maxVotes"
          best_count = remaining.map { |c| approvers[c].length }.max
          remaining = remaining.select { |c| approvers[c].length == best_count }
        when "minCost"
          best_cost = remaining.map { |c| cost[c] }.min
          remaining = remaining.select { |c| cost[c] == best_cost }
        when "maxCost"
          best_cost = remaining.map { |c| cost[c] }.max
          remaining = remaining.select { |c| cost[c] == best_cost }
        when Hash
          order = lexico_order(method)
          pos = order.each_with_index.to_h
          remaining = [remaining.min_by { |c| pos[c] || order.length }]
        else
          raise ComputeError, "Unknown tie-breaking method: #{method}" unless method.is_a?(Array)

          # JS-faithful reproduction of breakTies: iterate the *choices* and keep the
          # first that appears anywhere in the list. NOTE this does NOT respect the
          # list's ordering (it falls back to the choices' internal order) — for an
          # order-respecting total order use { lexico: [...] } instead. Kept only for
          # bit-compatibility with the equalshares.net tool, which never exercises it.
          remaining.each do |c|
            if method.include?(c)
              remaining = [c]
              break
            end
          end
        end
      end

      raise ComputeError, "Tie-breaking failed in a way that should not happen: #{choices}" if remaining.empty?

      remaining
    end

    # A total order of all projects induced by params.tie_breaking, used by rules that
    # need a full ordering (e.g. greedy welfare) rather than resolving a single tie.
    # Projects are sorted by the tie-breaking methods in priority order, falling back
    # to their original (JS Object.keys) order. Mirrors pabutools using
    # tie_breaking.order(...) as the base ordering.
    def total_order(project_ids, cost, approvers, params)
      base_index = {}
      project_ids.each_with_index { |c, i| base_index[c] = i }

      project_ids.sort_by do |c|
        key = params.tie_breaking.map do |method|
          case method
          when "maxVotes" then -approvers[c].length
          when "minCost" then cost[c]
          when "maxCost" then -cost[c]
          when Hash
            order = lexico_order(method)
            order.index(c) || order.length
          else
            # explicit candidate-order list: earlier in the list ranks first
            method.is_a?(Array) ? (method.index(c) || method.length) : 0
          end
        end
        key + [base_index[c]]
      end
    end

    def lexico_order(method)
      order = method[:lexico] || method["lexico"]
      raise ComputeError, "Unknown tie-breaking method: #{method}" unless order.is_a?(Array)

      order
    end
  end
end
