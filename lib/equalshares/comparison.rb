# frozen_string_literal: true

module Equalshares
  # Comparison step. Faithful port of comparisonStep() in
  # js/methodOfEqualSharesWorker.js. Compares the MES committee against the greedy
  # committee; if a strict majority of voters prefer greedy, the outcome switches.
  module Comparison
    module_function

    def comparison_step(voter_ids, approvers, greedy, winners, params)
      prefers_mes = 0
      prefers_greedy = 0

      case params.comparison
      when "satisfaction"
        mes_satisfaction = Hash.new(0)
        greedy_satisfaction = Hash.new(0)
        [[winners, mes_satisfaction], [greedy, greedy_satisfaction]].each do |candidates, satisfaction|
          candidates.each do |c|
            approvers[c].each { |i| satisfaction[i] += 1 }
          end
        end
        voter_ids.each do |i|
          if mes_satisfaction[i] > greedy_satisfaction[i]
            prefers_mes += 1
          elsif greedy_satisfaction[i] > mes_satisfaction[i]
            prefers_greedy += 1
          end
        end
      when "exclusionRatio"
        mes_approvals = {}
        winners.each { |c| approvers[c].each { |i| mes_approvals[i] = true } }
        greedy_approvals = {}
        greedy.each { |c| approvers[c].each { |i| greedy_approvals[i] = true } }
        voter_ids.each do |i|
          if mes_approvals[i] && !greedy_approvals[i]
            prefers_mes += 1
          elsif greedy_approvals[i] && !mes_approvals[i]
            prefers_greedy += 1
          end
        end
      end

      stick_to_mes = prefers_greedy <= prefers_mes
      { stick_to_mes: stick_to_mes, prefers_mes: prefers_mes, prefers_greedy: prefers_greedy }
    end
  end
end
