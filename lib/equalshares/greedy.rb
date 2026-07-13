# frozen_string_literal: true

module Equalshares
  # Greedy approximation of utilitarian welfare, generalised over a satisfaction
  # measure. Faithful port of pabutools' greedy_utilitarian_welfare (additive,
  # resolute case).
  #
  # Projects are picked in order of decreasing "satisfaction density" = total
  # satisfaction of the project divided by its cost, resolving ties by the tie-breaking
  # order; any project that still fits the remaining budget is taken (knapsack greedy).
  #
  # For Cost_Sat the density is the approver count, so this coincides with the
  # equalshares.net utilitarian completion; for Cardinality_Sat it is approvers/cost.
  module Greedy
    module_function

    def utilitarian_welfare(instance, params = Params.new)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      election = Election.new(instance, params)
      project_ids = election.project_ids
      approvers = election.approvers
      sat = Satisfaction.for(params.satisfaction)

      cost = election.costs
      budget_limit = election.budget

      density = lambda do |c|
        total_sat = sat.call(cost[c], approvers[c].length) * approvers[c].length
        if total_sat.positive?
          cost[c].positive? ? total_sat / cost[c] : Float::INFINITY
        else
          0
        end
      end

      order = Tie.total_order(project_ids, cost, approvers, params)
      order_index = {}
      order.each_with_index { |c, i| order_index[c] = i }
      ranked = project_ids.sort_by { |c| [-density.call(c), order_index[c]] }

      winners = []
      remaining_budget = budget_limit
      ranked.each do |c|
        next unless cost[c] <= remaining_budget

        winners << c
        remaining_budget -= cost[c]
      end

      notes = { stats: election.statistics(winners) }
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      notes[:time] = format("%.1f", end_time - start_time)

      { winners: winners, notes: notes }
    end
  end
end
