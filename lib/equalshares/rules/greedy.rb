# frozen_string_literal: true

module Equalshares
  module Rules
    # Greedy approximation of utilitarian welfare, generalised over a satisfaction
    # measure. Faithful port of pabutools' greedy_utilitarian_welfare (additive,
    # resolute case).
    #
    # Projects are picked in order of decreasing "satisfaction density" = total
    # satisfaction of the project divided by its cost, resolving ties by the
    # tie-breaking order; any project that still fits the remaining budget is taken
    # (knapsack greedy). For Cost_Sat the density is the approver count.
    class Greedy < Base
      def call
        start = now
        project_ids = election.project_ids
        approvers = election.approvers
        cost = election.costs
        sat = Satisfaction.for(params.satisfaction)

        order = Tie.total_order(project_ids, cost, approvers, params)
        order_index = order.each_with_index.to_h
        ranked = project_ids.sort_by { |c| [-density(c, cost, approvers, sat), order_index[c]] }

        winners = []
        remaining_budget = election.budget
        ranked.each do |c|
          next unless cost[c] <= remaining_budget

          winners << c
          remaining_budget -= cost[c]
        end

        result(winners, start)
      end

      private

      def density(project_id, cost, approvers, sat)
        total_sat = sat.call(cost[project_id], approvers[project_id].length) * approvers[project_id].length
        if total_sat.positive?
          cost[project_id].positive? ? total_sat / cost[project_id] : Float::INFINITY
        else
          0
        end
      end
    end
  end
end
