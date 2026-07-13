# frozen_string_literal: true

module Equalshares
  module Rules
    # The maximin support rule (Aziz, Lee & Talmon 2018; "Generalised Sequential
    # Phragmén"), for approval ballots. Faithful port of pabutools' maximin_support.
    #
    # At each step, for every still-affordable project, the minimum achievable maximum
    # voter load of the committee W ∪ {c} is computed, and the project minimising it is
    # bought. Rather than an LP (as pabutools uses), the minimum max-load is computed
    # exactly: it equals the max-density subgraph value
    #     z*(W) = max_{S ⊆ W, S≠∅} cost(S) / |approvers(S)|
    # solved via a parametric max-flow (Dinkelbach iterations) in exact rational
    # arithmetic. This keeps the rule pure-Ruby, dependency-free and exact.
    #
    # Requires integer project costs (as in real pabulib data).
    class Maximin < Base
      def call
        start = now
        project_ids = election.project_ids
        approvers = election.approvers
        # maximin needs integer costs to scale the max-flow network exactly.
        cost = project_ids.to_h { |c| [c, integer_cost(instance.projects[c]["cost"])] }
        budget_limit = integer_cost(instance.budget)

        available = project_ids.select { |c| cost[c].between?(0, budget_limit) }
        winners = []
        remaining_budget = budget_limit

        loop do
          available = available.select { |c| !winners.include?(c) && cost[c] <= remaining_budget }
          break if available.empty?

          argmin = argmin_by_load(available, winners, cost, approvers)
          selected = break_tie(argmin, cost, approvers)

          winners << selected
          remaining_budget -= cost[selected]
          progress&.call((100 * winners.sum { |c| cost[c] } / budget_limit).floor)
        end

        result(winners, start)
      end

      private

      def argmin_by_load(available, winners, cost, approvers)
        min_load = nil
        argmin = []
        available.each do |c|
          load = min_max_load(winners + [c], cost, approvers)
          if min_load.nil? || load < min_load
            min_load = load
            argmin = [c]
          elsif load == min_load
            argmin << c
          end
        end
        argmin
      end

      def break_tie(argmin, cost, approvers)
        selected = Tie.break_ties(election.project_ids, cost, approvers, params, argmin)
        if selected.length > 1
          raise ComputeError,
                "Tie-breaking failed: tie between projects #{selected.join(', ')} could not be resolved."
        end
        selected[0]
      end

      # Minimum achievable maximum voter load for the committee, in exact rationals.
      # Equals the max-density subgraph value; Float::INFINITY if some project has cost
      # but no approvers (its cost cannot be distributed).
      def min_max_load(committee, cost, approvers)
        projects = committee.select { |c| cost[c].positive? }
        return 0 if projects.empty?
        return Float::INFINITY if projects.any? { |c| approvers[c].empty? }

        total_cost = projects.sum { |c| cost[c] }
        density = Rational(0)
        (projects.length + 2).times do
          source_side = feasible_or_violating_set(projects, cost, approvers, density, total_cost)
          return density if source_side.nil? # feasible at this level: density is optimal

          covered = source_side.flat_map { |c| approvers[c] }.uniq.length
          density = Rational(source_side.sum { |c| cost[c] }, covered)
        end
        density
      end

      # Build the parametric max-flow at load level `density` and return the set of
      # projects on the source side of the min cut (a set denser than `density`), or nil
      # if the whole cost can be routed (density is >= the true max-density).
      def feasible_or_violating_set(projects, cost, approvers, density, total_cost)
        den = density.denominator
        num = density.numerator
        voters = projects.flat_map { |c| approvers[c] }.uniq

        source = 0
        sink = 1
        project_node = {}
        projects.each_with_index { |c, i| project_node[c] = 2 + i }
        voter_node = {}
        voters.each_with_index { |v, i| voter_node[v] = 2 + projects.length + i }

        flow = MaxFlow.new(2 + projects.length + voters.length)
        infinity = total_cost * den # >= any single project's scaled cost
        projects.each do |c|
          flow.add_edge(source, project_node[c], cost[c] * den)
          approvers[c].each { |v| flow.add_edge(project_node[c], voter_node[v], infinity) }
        end
        voters.each { |v| flow.add_edge(voter_node[v], sink, num) }

        pushed = flow.max_flow(source, sink)
        return nil if pushed == total_cost * den # all cost routed -> feasible

        reachable = flow.reachable_from(source)
        projects.select { |c| reachable[project_node[c]] }
      end

      def integer_cost(value)
        Integer(value.to_s)
      rescue ArgumentError, TypeError
        raise ComputeError, "The maximin support rule requires integer costs (got #{value.inspect})"
      end
    end
  end
end
