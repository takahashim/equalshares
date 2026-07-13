# frozen_string_literal: true

module Equalshares
  module Rules
    # Phragmén's sequential rule for approval participatory budgeting. Faithful port of
    # pabutools' sequential_phragmen (resolute case).
    #
    # Voters accumulate "load" (starting at 0). Buying a project raises all its
    # approvers to a common load level (sum of their loads + cost) / |approvers|. At
    # each step the project minimising that new maximum load is bought; the rule stops
    # once the next project to buy would exceed the budget.
    class Phragmen < Base
      def call
        start = now
        project_ids = election.project_ids
        approvers = election.approvers
        cost = election.costs
        budget_limit = election.budget
        approval_score = project_ids.to_h { |c| [c, approvers[c].length] }

        loads = Hash.new(0) # voter id -> current load
        remaining = project_ids.select { |c| cost[c] <= budget_limit }
        winners = []
        current_cost = 0

        loop do
          break if remaining.empty?

          min_maxload, argmin = min_new_maxload(remaining, approvers, loads, cost, approval_score)

          # Stop as soon as the next project to be bought would violate the budget.
          break if argmin.any? { |c| current_cost + cost[c] > budget_limit }

          selected = Tie.resolve_one(project_ids, cost, approvers, params, argmin)
          approvers[selected].each { |i| loads[i] = min_maxload }
          winners << selected
          current_cost += cost[selected]
          remaining.delete(selected)
          progress&.call((100 * current_cost / budget_limit).floor)
        end

        result(winners, start)
      end

      private

      def min_new_maxload(remaining, approvers, loads, cost, approval_score)
        min_maxload = nil
        argmin = []
        remaining.each do |c|
          new_maxload =
            if approval_score[c].zero?
              Float::INFINITY
            else
              (approvers[c].sum { |i| loads[i] } + cost[c]) / approval_score[c]
            end
          if min_maxload.nil? || new_maxload < min_maxload
            min_maxload = new_maxload
            argmin = [c]
          elsif new_maxload == min_maxload
            argmin << c
          end
        end
        [min_maxload, argmin]
      end
    end
  end
end
