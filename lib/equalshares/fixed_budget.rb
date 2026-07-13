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
  # Ruby's Hash preserves insertion order and mirrors JS Map semantics used for
  # `remaining` (re-assigning an existing key keeps its position; delete removes it).
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
        cost = cost_source.transform_values { |c| Election.to_rational(c) }
        b_total = Election.to_rational(budget_source)
      when "floats"
        cost = cost_source.transform_values { |c| Float(c) }
        b_total = Float(budget_source)
      else
        raise ComputeError, "Unknown accuracy parameter"
      end
      compute(voter_ids, project_ids, cost, approvers, b_total, params,
              report_details: report_details, progress: progress)
    end

    # Core loop. Generalises the shared logic of equalSharesFixedBudgetFractions/Floats
    # over an additive satisfaction measure (see Equalshares::Satisfaction): the payment
    # mechanics are unchanged (each project raises its full cost), while the selection
    # criterion is effective vote count = u(c) / maxPayment, with u(c) the per-approver
    # utility. For Cost_Sat (u = cost) this is exactly the original rule.
    def compute(voter_ids, project_ids, cost, approvers, b_total, params,
                report_details: false, progress: nil)
      sat = Satisfaction.for(params.satisfaction)
      n = voter_ids.length
      budget = {}
      voter_ids.each { |i| budget[i] = b_total / n }

      report = { money_behind_candidate: {}, effective_vote_count: {}, endowment: b_total.to_f / n }

      remaining = {} # candidate -> previous effective vote count
      project_ids.each do |c|
        if cost[c].positive? && !approvers[c].empty?
          # effective vote count when budgets are ample: u(c) * |approvers| / cost(c)
          remaining[c] = (sat.call(cost[c], approvers[c].length) * approvers[c].length) / cost[c]
        end
        report[:money_behind_candidate][c] = []
        report[:effective_vote_count][c] = []
      end

      winners = []
      loop do
        best = []
        best_eff_vote_count = 0
        max_payment_of = {} # candidate -> per-approver payment cap computed this round

        # Walk remaining candidates in order of decreasing previous effective vote count.
        # Stable descending sort (ties keep insertion order), matching JS Array.sort.
        remaining_sorted = remaining.keys.each_with_index
                                    .sort_by { |c, idx| [-remaining[c], idx] }
                                    .map(&:first)

        remaining_sorted.each do |c|
          previous_eff_vote_count = remaining[c]
          # c cannot beat the best so far (optimization only when not reporting details).
          break if previous_eff_vote_count < best_eff_vote_count && !report_details

          money_behind_now = approvers[c].sum(numeric_zero(b_total)) { |i| budget[i] }
          report[:money_behind_candidate][c] << money_behind_now.to_f
          if money_behind_now < cost[c]
            # c is not affordable
            remaining.delete(c)
            report[:effective_vote_count][c] << 0
            next
          end

          # Effective vote count: split the cost of c as equally as possible among
          # approvers. Sort a copy by budget so the instance's approver order is not
          # mutated during computation.
          supporters_by_budget = approvers[c].sort_by { |i| budget[i] }
          paid_so_far = 0
          denominator = supporters_by_budget.length # approvers who can afford the max payment
          supporters_by_budget.each do |i|
            max_payment = (cost[c] - paid_so_far) / denominator # if remaining approvers pay equally
            if max_payment > budget[i]
              # i cannot afford the max payment, so pays entire remaining budget
              paid_so_far += budget[i]
              denominator -= 1
            else
              eff_vote_count = sat.call(cost[c], approvers[c].length) / max_payment
              remaining[c] = eff_vote_count
              max_payment_of[c] = max_payment
              report[:effective_vote_count][c] << eff_vote_count.to_f
              if eff_vote_count > best_eff_vote_count
                best_eff_vote_count = eff_vote_count
                best = [c]
              elsif eff_vote_count == best_eff_vote_count
                best << c
              end
              break
            end
          end
        end

        if best.empty?
          # no remaining candidates are affordable
          unless remaining.empty?
            raise ComputeError,
                  "No available candidate found even though there are still affordable candidates: #{remaining.keys}"
          end

          break
        end

        best = Tie.resolve_one(project_ids, cost, approvers, params, best)
        winners << best
        progress&.call((100 * winners.sum { |c| cost[c] } / b_total).floor)

        # The actual per-approver payment cap (equals cost/eff only for Cost_Sat).
        best_max_payment = max_payment_of[best]
        approvers[best].each do |i|
          budget[i] = budget[i] > best_max_payment ? budget[i] - best_max_payment : numeric_zero(b_total)
        end
        remaining.delete(best)
      end

      { winners: winners, report: report }
    end

    # Additive identity in the same numeric family as the budget (0 or 0.0).
    def numeric_zero(b_total)
      b_total.is_a?(Float) ? 0.0 : 0
    end
  end
end
