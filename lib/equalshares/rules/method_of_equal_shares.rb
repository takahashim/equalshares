# frozen_string_literal: true

module Equalshares
  module Rules
    # The Method of Equal Shares for approval ballots — the equalshares.net rule,
    # including its completion methods (none/utilitarian/add1/...) and comparison step.
    # Faithful port of equalShares() in js/methodOfEqualSharesWorker.js.
    #
    # Cost and budget are treated as floats at this level (statistics, comparison,
    # utilitarian/greedy committees, the everything-affordable check); only the inner
    # fixed-budget MES loop switches to exact rationals for accuracy "fractions".
    class MethodOfEqualShares < Base
      ADD1_COMPLETIONS = %w[add1 add1e add1u add1eu].freeze
      UTILITARIAN_COMPLETIONS = %w[utilitarian add1u].freeze

      def call
        start = now
        voter_ids = election.voter_ids
        project_ids = election.project_ids
        approvers = election.approvers

        # Strings for the MES loop (it wraps them per accuracy); floats for the
        # completion/comparison/statistics bookkeeping (as the JS does).
        cost_source = project_ids.to_h { |c| [c, instance.projects[c]["cost"]] }
        cost = election.float_costs
        b_float = election.float_budget

        mes = run_mes(cost_source, instance.budget)
        winners = mes.fetch(:winners)
        report = mes.fetch(:report)
        notes = {
          endowment: report[:endowment],
          money_behind_candidate: report[:money_behind_candidate],
          effective_vote_count: report[:effective_vote_count]
        }

        # utilitarian completion if needed
        if UTILITARIAN_COMPLETIONS.include?(params.completion)
          completion = Completion.utilitarian(voter_ids, project_ids, cost, approvers, b_float, winners)
          winners = completion.fetch(:winners)
          notes[:added_by_utilitarian_completion] = completion.fetch(:added)
        end

        # comparison step
        greedy = Completion.utilitarian(voter_ids, project_ids, cost, approvers, b_float, []).fetch(:winners)
        unless params.comparison == "none"
          cmp = Comparison.comparison_step(voter_ids, approvers, greedy, winners, params)
          unless cmp[:stick_to_mes]
            winners = greedy
            notes[:comparison] =
              "The committee chosen by the greedy algorithm is preferred by #{cmp[:prefers_greedy]} voters, " \
              "while the committee chosen by the method of equal shares is preferred by #{cmp[:prefers_mes]} voters."
          end
        end

        notes[:greedy_stats] = election.statistics(greedy)
        result(winners, start, notes)
      end

      private

      def run_mes(cost_source, budget_source)
        voter_ids = election.voter_ids
        project_ids = election.project_ids
        approvers = election.approvers
        everything_affordable = election.float_costs.values.sum <= election.float_budget

        if %w[none utilitarian].include?(params.completion) || everything_affordable
          # don't use Add1 if everything is affordable
          FixedBudget.run(voter_ids, project_ids, cost_source, approvers, budget_source, params,
                          report_details: true, progress: progress)
        elsif ADD1_COMPLETIONS.include?(params.completion)
          Completion.add1(voter_ids, project_ids, cost_source, approvers, budget_source, params, progress: progress)
        else
          raise ComputeError, "Unknown completion rule: #{params.completion}"
        end
      end
    end
  end
end
