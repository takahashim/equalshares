# frozen_string_literal: true

module Equalshares
  # Completion methods. Faithful port of equalSharesAdd1() and utilitarianCompletion()
  # in js/methodOfEqualSharesWorker.js.
  module Completion
    module_function

    # Method of Equal Shares with Add1 completion: repeatedly re-run fixed-budget MES
    # with increasing per-voter budgets until adding more would exceed the real budget.
    def add1(voter_ids, project_ids, cost_source, approvers, budget_source, params, progress: nil)
      n = voter_ids.length
      b = Float(budget_source)

      start_budget = budget_source
      if params.add1_option?("integral")
        per_voter = (b / n).floor
        start_budget = per_voter * n
      end
      start_budget = to_number(start_budget)

      # The virtual budget is raised in steps of `step`. The linear scan (as in the JS tool)
      # stops at the first step whose outcome is either exhaustive (if enabled) or exceeds the
      # real budget b. Both stopping conditions are monotone in the number of steps (once true
      # they stay true as the budget grows), so we binary-search for the last accepted step and
      # compute O(log) fixed-budget outcomes instead of O(steps). The result is identical to the
      # scan: FixedBudget never mutates `approvers`, so the final reported run is independent of
      # which budgets were probed.
      step = n * params.increment
      exhaustive_enabled = params.add1_option?("exhaustive")
      memo = {}

      eval_step = lambda do |k|
        memo[k] ||= begin
          winners = FixedBudget.run(voter_ids, project_ids, cost_source, approvers,
                                    start_budget + (k * step), params).fetch(:winners)
          step_cost = winners.sum { |c| cost_float(cost_source, c) }
          exhaustive = exhaustive_enabled &&
                       project_ids.none? do |extra|
                         !winners.include?(extra) && step_cost + cost_float(cost_source, extra) <= b
                       end
          progress&.call((100 * [step_cost, b].min / b).floor)
          { winners: winners, cost: step_cost, exhaustive: exhaustive }
        end
      end

      # Would the linear scan reach and accept the budget at step k? Step 0 is the starting point;
      # step k >= 1 is accepted iff no earlier step was exhaustive and step k is still within
      # budget (monotonicity lets us test only the preceding exhaustiveness and this cost).
      accepts = lambda do |k|
        next true if k <= 0
        next false if exhaustive_enabled && eval_step.call(k - 1)[:exhaustive]

        eval_step.call(k)[:cost] <= b
      rescue ComputeError
        # Far above the accepted region the outcome can become unresolvable (e.g. an unbreakable
        # tie); the linear scan never reaches there, so treat it as past the boundary.
        false
      end

      # gallop to bracket the boundary, then binary-search the last accepted step
      hi = 1
      hi *= 2 while accepts.call(hi)
      lo = hi / 2 # accepts(lo) is true
      while lo + 1 < hi
        mid = (lo + hi) / 2
        accepts.call(mid) ? (lo = mid) : (hi = mid)
      end
      budget = start_budget + (lo * step)

      # recompute with final budget while reporting details
      FixedBudget.run(voter_ids, project_ids, cost_source, approvers, budget, params, report_details: true)
    end

    # Greedy completion by number of approvers (also used to build the greedy committee).
    # `cost` here is the numeric cost map (Float or Rational).
    def utilitarian(_voter_ids, project_ids, cost, approvers, budget_total, already_winners)
      winners = already_winners.dup
      cost_so_far = winners.sum { |c| cost[c] }
      added = []
      # Stable descending sort by approver count (ties keep original order), matching JS Array.sort.
      sorted = project_ids.each_with_index
                          .sort_by { |c, idx| [-approvers[c].length, idx] }
                          .map(&:first)
      sorted.each do |c|
        next if winners.include?(c) || cost_so_far + cost[c] > budget_total

        winners << c
        added << c
        cost_so_far += cost[c]
      end
      { winners: winners, added: added }
    end

    def cost_float(cost_source, cost_id)
      Float(cost_source[cost_id])
    end

    # Preserve integer budgets (Add1 increments are integral); fall back to float.
    def to_number(value)
      Integer(value.to_s)
    rescue ArgumentError, TypeError
      Float(value)
    end
  end
end
