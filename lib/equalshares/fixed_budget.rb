# frozen_string_literal: true

module Equalshares
  # The fixed-budget Method of Equal Shares loop.
  #
  # This unifies the two near-identical JS implementations
  # (equalSharesFixedBudgetFractions and equalSharesFixedBudgetFloats in
  # js/methodOfEqualSharesWorker.js) into a single loop driven by the numeric type
  # of the values passed in:
  #   - fractions mode: `cost` values and `b_total` are Rational  -> exact arithmetic
  #   - floats mode:    `cost` values and `b_total` are Float      -> IEEE-754 arithmetic
  #
  # The arithmetic (order and types) is kept bit-identical to the JS tool; the class
  # below only reorganises the control flow into evaluate/charge steps.
  module FixedBudget
    module_function

    # Dispatch on params.accuracy, preparing cost/budget in the right numeric type.
    # `cost_source` maps project_id => original cost string; `budget_source` is the
    # budget string. This mirrors JS where costs come from parseFloat, then (in the
    # fractions path) get wrapped by new Fraction(...).
    def run(voter_ids, project_ids, cost_source, approvers, budget_source, params,
            report_details: false, progress: nil)
      case params.accuracy
      when "fractions"
        cost = cost_source.transform_values { |c| Election.rational_of(c) }
        b_total = Election.rational_of(budget_source)
      when "floats"
        cost = cost_source.transform_values { |c| Float(c) }
        b_total = Float(budget_source)
      else
        raise ComputeError, "Unknown accuracy parameter"
      end
      Loop.new(voter_ids, project_ids, cost, approvers, b_total, params,
               report_details: report_details, progress: progress).run
    end

    # Collects the per-candidate explanation data produced while running the rule
    # (money behind each candidate and its effective vote count over the rounds, plus
    # the per-voter endowment). Kept separate from the selection logic; #to_h yields the
    # same hash shape the callers consume.
    class Report
      def initialize(project_ids, endowment)
        @endowment = endowment
        @money_behind_candidate = {}
        @effective_vote_count = {}
        project_ids.each do |c|
          @money_behind_candidate[c] = []
          @effective_vote_count[c] = []
        end
      end

      def record_money_behind(project_id, value)
        @money_behind_candidate[project_id] << value.to_f
      end

      def record_effective_vote_count(project_id, value)
        @effective_vote_count[project_id] << value.to_f
      end

      def record_unaffordable(project_id)
        @effective_vote_count[project_id] << 0
      end

      def to_h
        { money_behind_candidate: @money_behind_candidate,
          effective_vote_count: @effective_vote_count,
          endowment: @endowment }
      end
    end

    # One fixed-budget MES run. Generalises the shared logic of
    # equalSharesFixedBudgetFractions/Floats over an additive satisfaction measure (see
    # Equalshares::Satisfaction): the payment mechanics are unchanged (each project
    # raises its full cost), while the selection criterion is effective vote count =
    # u(c) / maxPayment, with u(c) the per-approver utility. For Cost_Sat (u = cost)
    # this is exactly the original rule.
    #
    # Ruby's Hash preserves insertion order and mirrors the JS Map semantics used for
    # `remaining` (re-assigning an existing key keeps its position; delete removes it).
    class Loop
      CandidateEvaluation = Struct.new(:project_id, :money_behind, :effective_vote_count,
                                       :max_payment, :affordable?, keyword_init: true)

      def initialize(voter_ids, project_ids, cost, approvers, b_total, params,
                     report_details: false, progress: nil)
        @project_ids = project_ids
        @cost = cost
        @approvers = approvers
        @b_total = b_total
        @params = params
        @report_details = report_details
        @progress = progress
        @sat = Satisfaction.for(params.satisfaction)
        @n = voter_ids.length

        initialize_budget(voter_ids)
        initialize_report
        initialize_remaining
      end

      def run
        winners = []
        loop do
          best, max_payment_of = select_best
          if best.empty?
            # no remaining candidates are affordable
            unless @remaining.empty?
              raise ComputeError,
                    "No available candidate found even though there are still affordable candidates: " \
                    "#{@remaining.keys}"
            end

            break
          end

          best = Tie.resolve_one(@project_ids, @cost, @approvers, @params, best)
          winners << best
          @progress&.call((100 * winners.sum { |c| @cost[c] } / @b_total).floor)
          charge_winner(best, max_payment_of[best])
          @remaining.delete(best)
        end

        { winners: winners, report: @report.to_h }
      end

      private

      def initialize_budget(voter_ids)
        @budget = {}
        voter_ids.each { |i| @budget[i] = @b_total / @n }
      end

      def initialize_report
        @report = Report.new(@project_ids, @b_total.to_f / @n)
      end

      def initialize_remaining
        @remaining = {} # candidate -> previous effective vote count
        @project_ids.each do |c|
          next unless @cost[c].positive? && !@approvers[c].empty?

          # effective vote count when budgets are ample: u(c) * |approvers| / cost(c)
          @remaining[c] =
            (@sat.call(@cost[c], @approvers[c].length) * @approvers[c].length) / @cost[c]
        end
      end

      # Pick the affordable candidate(s) with the highest effective vote count this
      # round, returning [tied_best, max_payment_by_candidate].
      def select_best
        best = []
        best_eff_vote_count = 0
        max_payment_of = {} # candidate -> per-approver payment cap computed this round

        # Walk remaining candidates in order of decreasing previous effective vote count.
        # Stable descending sort (ties keep insertion order), matching JS Array.sort.
        remaining_sorted = @remaining.keys.each_with_index
                                     .sort_by { |c, idx| [-@remaining[c], idx] }
                                     .map(&:first)

        remaining_sorted.each do |c|
          # c cannot beat the best so far (optimization only when not reporting details).
          break if @remaining[c] < best_eff_vote_count && !@report_details

          evaluation = evaluate_candidate(c)
          record_evaluation(evaluation)
          next unless evaluation.affordable?

          max_payment_of[c] = evaluation.max_payment
          if evaluation.effective_vote_count > best_eff_vote_count
            best_eff_vote_count = evaluation.effective_vote_count
            best = [c]
          elsif evaluation.effective_vote_count == best_eff_vote_count
            best << c
          end
        end

        [best, max_payment_of]
      end

      # Effective vote count and per-approver payment cap for candidate c this round, or
      # an unaffordable result if c cannot raise its cost with current supporter budgets.
      def evaluate_candidate(project_id)
        money_behind_now = @approvers[project_id].sum(numeric_zero) { |i| @budget[i] }
        if money_behind_now < @cost[project_id]
          return CandidateEvaluation.new(project_id: project_id, money_behind: money_behind_now,
                                         effective_vote_count: 0,
                                         max_payment: nil, affordable?: false)
        end

        # Split the cost as equally as possible among approvers. Sort a copy by budget so
        # the instance's approver order is not mutated during computation.
        supporters_by_budget = @approvers[project_id].sort_by { |i| @budget[i] }
        paid_so_far = 0
        denominator = supporters_by_budget.length # approvers who can afford the max payment
        supporters_by_budget.each do |i|
          max_payment = (@cost[project_id] - paid_so_far) / denominator # if remaining approvers pay equally
          if max_payment > @budget[i]
            # i cannot afford the max payment, so pays entire remaining budget
            paid_so_far += @budget[i]
            denominator -= 1
          else
            eff_vote_count = @sat.call(@cost[project_id], @approvers[project_id].length) / max_payment
            return CandidateEvaluation.new(project_id: project_id, money_behind: money_behind_now,
                                           effective_vote_count: eff_vote_count,
                                           max_payment: max_payment, affordable?: true)
          end
        end
        raise ComputeError, "Candidate #{project_id} was affordable but no payment cap could be computed."
      end

      # Apply an evaluation: update the core `remaining` state and record the numbers in
      # the report (the latter delegated to the Report collaborator).
      def record_evaluation(evaluation)
        project_id = evaluation.project_id
        @report.record_money_behind(project_id, evaluation.money_behind)

        if evaluation.affordable?
          @remaining[project_id] = evaluation.effective_vote_count
          @report.record_effective_vote_count(project_id, evaluation.effective_vote_count)
        else
          @remaining.delete(project_id)
          @report.record_unaffordable(project_id)
        end
      end

      # Charge each approver of the winning candidate its per-approver payment cap
      # (equals cost/eff only for Cost_Sat), capped at their remaining budget.
      def charge_winner(best, best_max_payment)
        @approvers[best].each do |i|
          @budget[i] = @budget[i] > best_max_payment ? @budget[i] - best_max_payment : numeric_zero
        end
      end

      # Additive identity in the same numeric family as the budget (0 or 0.0).
      def numeric_zero
        @b_total.is_a?(Float) ? 0.0 : 0
      end
    end
  end
end
