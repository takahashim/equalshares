# frozen_string_literal: true

module Equalshares
  module Rules
    # Method of Equal Shares for ballots carrying per-voter utilities (vote_type
    # "scoring"/"cumulative", or "ordinal" via Borda), where each voter i has a
    # per-project utility u_i(c). Faithful port of the core of pabutools'
    # method_of_equal_shares with an additive satisfaction (the "poor/rich"
    # affordability computation), for the pure rule (no completion).
    #
    # The approval path (Rules::MethodOfEqualShares) is kept separate; this general
    # path is used when instance.cardinal? is true.
    class CardinalMes < Base
      def call
        unless instance.cardinal?
          raise ComputeError,
                "CardinalMes applies to instances with per-voter scores (scoring/cumulative/ordinal)"
        end

        start = now
        voter_ids = election.voter_ids
        project_ids = election.project_ids
        approvers = election.approvers
        cost = election.costs
        budget_limit = election.budget
        util = project_ids.to_h { |c| [c, election.utilities(c)] }
        n = voter_ids.length

        budget = {}
        voter_ids.each { |i| budget[i] = budget_limit / n } # endowment B/|N|

        remaining = project_ids.select { |c| cost[c].positive? && !approvers[c].empty? }
        winners = []

        loop do
          argmin = argmin_by_affordability(remaining, approvers, budget, util, cost)
          break if argmin.empty?

          selected = break_tie(argmin, cost, approvers)
          charge(selected, approvers, budget, util, cost)
          winners << selected
          remaining.delete(selected)
          progress&.call((100 * winners.sum { |c| cost[c] } / budget_limit).floor)
        end

        result(winners, start)
      end

      private

      def argmin_by_affordability(remaining, approvers, budget, util, cost)
        min_rho = nil
        argmin = []
        remaining.dup.each do |c|
          supporters = approvers[c]
          if supporters.sum { |i| budget[i] } < cost[c]
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
        argmin
      end

      def charge(selected, approvers, budget, util, cost)
        rho = affordability(approvers[selected], budget, util[selected], cost[selected])
        zero = election.exact? ? 0 : 0.0
        approvers[selected].each do |i|
          payment = rho * util[selected][i]
          budget[i] = budget[i] > payment ? budget[i] - payment : zero
        end
      end

      def break_tie(argmin, cost, approvers)
        selected = Tie.break_ties(election.project_ids, cost, approvers, params, argmin)
        if selected.length > 1
          raise ComputeError,
                "Tie-breaking failed: tie between projects #{selected.join(', ')} could not be resolved."
        end
        selected[0]
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
end
