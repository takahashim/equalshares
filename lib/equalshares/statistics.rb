# frozen_string_literal: true

module Equalshares
  # Outcome statistics. Faithful port of gatherOutcomeStatistics() in
  # js/methodOfEqualSharesWorker.js.
  module Statistics
    module_function

    # `cost` is the numeric cost map (Float or Rational).
    def gather(voter_ids, cost, approvers, winners)
      n = voter_ids.length
      total_cost = winners.sum { |c| cost[c] }
      avg_approved_projects = winners.sum { |c| approvers[c].length }.to_f / n
      avg_cost_of_winning_approved = winners.sum { |c| approvers[c].length * cost[c] }.to_f / n

      voter_utility = Hash.new(0)
      winners.each do |c|
        approvers[c].each { |i| voter_utility[i] += 1 }
      end

      # For each r, how many voters approve exactly r winning projects?
      utility_distribution = {}
      (0..winners.length).each { |util| utility_distribution[util] = 0 }
      voter_ids.each { |i| utility_distribution[voter_utility[i]] += 1 }

      {
        total_cost: total_cost,
        avg_approved_projects: avg_approved_projects,
        avg_cost_of_winning_approved_projects: avg_cost_of_winning_approved,
        utility_distribution: utility_distribution
      }
    end
  end
end
