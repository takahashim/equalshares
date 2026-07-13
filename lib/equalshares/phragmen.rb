# frozen_string_literal: true

module Equalshares
  # Phragmén's sequential rule for approval participatory budgeting.
  # Faithful port of pabutools' sequential_phragmen (resolute case).
  #
  # Voters accumulate "load" (starting at 0). Buying a project raises all its
  # approvers to a common load level (sum of their loads + cost) / |approvers|. At
  # each step the project minimising that new maximum load is bought; the rule stops
  # once the next project to buy would exceed the budget.
  module Phragmen
    module_function

    def sequential(instance, params = Params.new, progress: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      voter_ids = instance.voter_ids
      project_ids = instance.project_ids
      approvers = instance.approvers
      exact = params.accuracy == "fractions"

      cost = project_ids.to_h { |c| [c, numeric(instance.projects[c]["cost"], exact)] }
      budget_limit = numeric(instance.budget, exact)
      approval_score = project_ids.to_h { |c| [c, approvers[c].length] }

      loads = Hash.new(0) # voter id -> current load
      remaining = project_ids.select { |c| cost[c] <= budget_limit }
      winners = []
      current_cost = 0

      loop do
        break if remaining.empty?

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

        # Stop as soon as the next project to be bought would violate the budget.
        break if argmin.any? { |c| current_cost + cost[c] > budget_limit }

        selected = Tie.break_ties(project_ids, cost, approvers, params, argmin)
        if selected.length > 1
          raise ComputeError,
                "Tie-breaking failed: tie between projects #{selected.join(', ')} could not be resolved."
        end
        selected = selected[0]

        approvers[selected].each { |i| loads[i] = min_maxload }
        winners << selected
        current_cost += cost[selected]
        remaining.delete(selected)
        progress&.call((100 * current_cost / budget_limit).floor)
      end

      cost_float = project_ids.to_h { |c| [c, Float(instance.projects[c]["cost"])] }
      notes = { stats: Statistics.gather(voter_ids, cost_float, approvers, winners) }
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      notes[:time] = format("%.1f", end_time - start_time)

      { winners: winners, notes: notes }
    end

    def numeric(value, exact)
      exact ? FixedBudget.to_rational(value) : Float(value)
    end
  end
end
