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

      mes = FixedBudget.run(voter_ids, project_ids, cost_source, approvers, start_budget, params,
                            progress: progress).fetch(:winners)
      current_cost = mes.sum { |c| cost_float(cost_source, c) }
      progress&.call((100 * current_cost / b).floor)

      budget = to_number(start_budget)
      loop do
        if params.add1_option?("exhaustive")
          exhaustive = project_ids.none? do |extra|
            !mes.include?(extra) && current_cost + cost_float(cost_source, extra) <= b
          end
          break if exhaustive
        end

        next_budget = budget + (n * params.increment)
        next_mes = FixedBudget.run(voter_ids, project_ids, cost_source, approvers, next_budget, params)
                              .fetch(:winners)
        current_cost = next_mes.sum { |c| cost_float(cost_source, c) }
        break unless current_cost <= b

        progress&.call((100 * current_cost / b).floor)
        budget = next_budget
        mes = next_mes
      end

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
