# frozen_string_literal: true

module Equalshares
  # Top-level Method of Equal Shares computation.
  # Faithful port of equalShares() and the worker onmessage handler in
  # js/methodOfEqualSharesWorker.js.
  #
  # Note: like the JS, cost and budget are treated as floats everywhere at this
  # level (statistics, comparison, utilitarian/greedy committees, the
  # everything-affordable check). Only the fixed-budget MES loop switches to exact
  # Rational arithmetic when params.accuracy == "fractions".
  module Compute
    module_function

    ADD1_COMPLETIONS = %w[add1 add1e add1u add1eu].freeze
    UTILITARIAN_COMPLETIONS = %w[utilitarian add1u].freeze

    # Returns { winners: Array<String>, notes: Hash }.
    def equal_shares(instance, params = Params.new, progress: nil)
      # Cardinal ballots use per-voter utilities; delegate to the general MES (pure
      # rule). The completion/comparison variants below are approval/cost-specific.
      return MesGeneral.equal_shares(instance, params, progress: progress) if instance.cardinal?

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      voter_ids = instance.voter_ids
      project_ids = instance.project_ids

      cost_source = project_ids.to_h { |c| [c, instance.projects[c]["cost"]] }
      budget_source = instance.budget

      # Float views used at this level (mirrors parseFloat in the JS).
      cost = cost_source.transform_values { |c| Float(c) }
      b_float = Float(budget_source)

      everything_affordable = cost.values.sum <= b_float

      result =
        if %w[none utilitarian].include?(params.completion) || everything_affordable
          # don't use Add1 if everything is affordable
          FixedBudget.run(voter_ids, project_ids, cost_source, approvers(instance), budget_source, params,
                          report_details: true, progress: progress)
        elsif ADD1_COMPLETIONS.include?(params.completion)
          Completion.add1(voter_ids, project_ids, cost_source, approvers(instance), budget_source, params,
                          progress: progress)
        else
          raise ComputeError, "Unknown completion rule: #{params.completion}"
        end

      winners = result.fetch(:winners)
      report = result.fetch(:report)
      notes = {
        endowment: report[:endowment],
        money_behind_candidate: report[:money_behind_candidate],
        effective_vote_count: report[:effective_vote_count]
      }

      # utilitarian completion if needed
      if UTILITARIAN_COMPLETIONS.include?(params.completion)
        completion_result = Completion.utilitarian(voter_ids, project_ids, cost, approvers(instance), b_float, winners)
        winners = completion_result.fetch(:winners)
        notes[:added_by_utilitarian_completion] = completion_result.fetch(:added)
      end

      # comparison step
      greedy = Completion.utilitarian(voter_ids, project_ids, cost, approvers(instance), b_float, []).fetch(:winners)
      unless params.comparison == "none"
        cmp = Comparison.comparison_step(voter_ids, approvers(instance), greedy, winners, params)
        unless cmp[:stick_to_mes]
          winners = greedy
          notes[:comparison] =
            "The committee chosen by the greedy algorithm is preferred by #{cmp[:prefers_greedy]} voters, " \
            "while the committee chosen by the method of equal shares is preferred by #{cmp[:prefers_mes]} voters."
        end
      end

      notes[:stats] = Statistics.gather(voter_ids, cost, approvers(instance), winners)
      notes[:greedy_stats] = Statistics.gather(voter_ids, cost, approvers(instance), greedy)

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      notes[:time] = format("%.1f", end_time - start_time)

      { winners: winners, notes: notes }
    end

    # The algorithm mutates approvers[c] (in-place sort in the MES loop), so hand it
    # the instance's own map — matching the JS which also mutates instance.approvers.
    def approvers(instance)
      instance.approvers
    end
  end
end
