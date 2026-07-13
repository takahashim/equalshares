# frozen_string_literal: true

module Equalshares
  # Method of Equal Shares for cardinal ballots (vote_type "scoring"/"cumulative"),
  # where each voter i has a per-project utility u_i(c) = score. Faithful port of the
  # core of pabutools' method_of_equal_shares with an additive cardinal satisfaction
  # (the "poor/rich" affordability computation), for the pure rule (no completion).
  #
  # The approval path (Compute/FixedBudget) is kept separate and unchanged; this
  # general path is used when instance.cardinal? is true.
  module MesGeneral
    module_function

    def equal_shares(instance, params = Params.new, progress: nil)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      unless instance.cardinal?
        raise ComputeError,
              "MesGeneral applies to instances with per-voter scores (scoring/cumulative/ordinal)"
      end

      election = Election.new(instance, params)
      voter_ids = election.voter_ids
      project_ids = election.project_ids
      approvers = election.approvers
      n = voter_ids.length

      cost = election.costs
      budget_limit = election.budget
      util = project_ids.to_h { |c| [c, election.utilities(c)] }
      exact = election.exact?

      budget = {}
      voter_ids.each { |i| budget[i] = budget_limit / n } # endowment B/|N|

      remaining = project_ids.select { |c| cost[c].positive? && !approvers[c].empty? }
      winners = []

      loop do
        min_rho = nil
        argmin = []
        remaining.dup.each do |c|
          supporters = approvers[c]
          total_budget = supporters.sum { |i| budget[i] }
          if total_budget < cost[c]
            remaining.delete(c) # can never become affordable again
            next
          end
          rho = affordability(supporters, budget, util[c], cost[c])
          if min_rho.nil? || rho < min_rho
            min_rho = rho
            argmin = [c]
          elsif rho == min_rho
            argmin << c
          end
        end

        break if argmin.empty?

        selected = Tie.break_ties(project_ids, cost, approvers, params, argmin)
        if selected.length > 1
          raise ComputeError,
                "Tie-breaking failed: tie between projects #{selected.join(', ')} could not be resolved."
        end
        selected = selected[0]

        rho = affordability(approvers[selected], budget, util[selected], cost[selected])
        approvers[selected].each do |i|
          payment = rho * util[selected][i]
          budget[i] = if budget[i] > payment
                        budget[i] - payment
                      else
                        (exact ? 0 : 0.0)
                      end
        end
        winners << selected
        remaining.delete(selected)
        progress&.call((100 * winners.sum { |c| cost[c] } / budget_limit).floor)
      end

      notes = { stats: election.statistics(winners) }
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      notes[:time] = format("%.1f", end_time - start_time)

      { winners: winners, notes: notes }
    end

    # The "poor/rich" affordability factor rho: minimal rho such that
    # sum_i min(budget_i, rho * u_i(c)) == cost(c). Port of pabutools'
    # affordability_poor_rich.
    def affordability(supporters, budget, util, cost)
      rich = supporters.dup
      poor_budget = 0
      loop do
        denominator = rich.sum { |i| util[i] }
        rho = (cost - poor_budget) / denominator
        new_poor = rich.select { |i| budget[i] < rho * util[i] }
        return rho if new_poor.empty?

        poor_budget += new_poor.sum { |i| budget[i] }
        rich -= new_poor
      end
    end
  end
end
