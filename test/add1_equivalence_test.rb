# frozen_string_literal: true

require_relative "test_helper"

# Equivalence guard for the Add1 binary-search optimisation in Completion.add1.
#
# The optimisation replaced a linear budget scan with a bisection, relying on the premise
# that the two stopping conditions ("the outcome is exhaustive" and "the outcome exceeds
# the real budget") are monotone in the number of increment steps. That premise otherwise
# lives only in a code comment, so this test pins it executably: a reference linear scan
# (the pre-optimisation algorithm) is kept here and compared against the production
# bisection over real fixtures, both accuracies and every add1_options combination. If any
# instance ever broke the monotonicity, the scan and the bisection would settle on
# different budgets and this test would name the case instead of the code silently
# returning a different result.
#
# Two things keep the reference well-defined and fast: increments are sized so the (slow)
# linear scan runs in a handful of steps, and a resolving tie_breaking is used so both
# paths complete. The regime where the scan hits an unbreakable tie at an intermediate
# budget — where it raises while the bisection skips over it — is deliberately out of
# scope, because there the original algorithm has no defined result to match.
class Add1EquivalenceTest < Minitest::Test
  include TestSupport

  # Increment per fixture, chosen so the linear reference scans only a handful of steps.
  FIXTURE_INCREMENTS = {
    "hungary_budapest_2024.pb" => 100_000,
    "netherlands_amsterdam_2022_west.pb" => 60,
    "poland_warszawa_2021_bielany.pb" => 150
  }.freeze

  TIE_BREAKING = %w[maxVotes minCost maxCost].freeze

  # floats exercise the monotonicity/boundary logic across all option combinations; a
  # couple of fractions cases confirm the exact-arithmetic path agrees too.
  ACCURACY_OPTION_SETS = {
    "floats" => [%w[exhaustive integral], %w[integral], %w[exhaustive], []],
    "fractions" => [%w[exhaustive integral], []]
  }.freeze

  def test_bisection_matches_linear_scan
    count = 0
    FIXTURE_INCREMENTS.each do |fixture, increment|
      instance = load_fixture(fixture)
      ACCURACY_OPTION_SETS.each do |accuracy, option_sets|
        option_sets.each do |add1_options|
          params = build_params(accuracy, add1_options, increment)
          expected = linear_scan_add1(instance, params)
          actual = Equalshares::Completion.add1(*add1_args(instance), params)
          label = "#{fixture} #{accuracy} [#{add1_options.join(',')}] inc=#{increment}"
          assert_equal expected[:winners], actual[:winners], "winners mismatch: #{label}"
          assert_equal expected[:report], actual[:report], "report mismatch: #{label}"
          count += 1
        end
      end
    end
    assert_operator count, :>=, 18, "expected the full fixture/accuracy/options matrix to run"
  end

  # The equivalence rests on FixedBudget never reordering `approvers`, which is what makes
  # the final reported run independent of which budgets the search probed. Pin it directly
  # so a future change that reintroduces in-place mutation fails loudly here.
  def test_add1_does_not_mutate_approvers
    FIXTURE_INCREMENTS.each do |fixture, increment|
      instance = load_fixture(fixture)
      approvers = instance.approvers
      before = approvers.transform_values(&:dup)
      params = build_params("floats", %w[exhaustive integral], increment)
      Equalshares::Completion.add1(instance.voter_ids, instance.project_ids,
                                   cost_source(instance), approvers, instance.budget, params)
      assert_equal before, approvers, "add1 must not reorder approvers (#{fixture})"
    end
  end

  private

  def load_fixture(fixture)
    Equalshares::Pabulib.parse_file(File.join(__dir__, "fixtures", "pb", fixture))
  end

  def build_params(accuracy, add1_options, increment)
    Equalshares::Params.new(completion: "add1", tie_breaking: TIE_BREAKING,
                            add1_options: add1_options, accuracy: accuracy, increment: increment)
  end

  def cost_source(instance)
    instance.project_ids.to_h { |c| [c, instance.projects[c]["cost"]] }
  end

  # A fresh approver copy per call keeps each run's input in pristine parse order.
  def add1_args(instance)
    [instance.voter_ids, instance.project_ids, cost_source(instance),
     instance.approvers.transform_values(&:dup), instance.budget]
  end

  # The Add1 sweep exactly as it was before the bisection: raise the budget one increment
  # at a time, stopping at the first exhaustive or over-budget step. Reuses Completion's
  # own cost/number helpers so it stays faithful to the production numeric handling.
  def linear_scan_add1(instance, params)
    voter_ids, project_ids, cost_source, approvers, budget_source = add1_args(instance)
    completion = Equalshares::Completion
    n = voter_ids.length
    b = Float(budget_source)

    start_budget = budget_source
    start_budget = (b / n).floor * n if params.add1_option?("integral")

    mes = Equalshares::FixedBudget.run(voter_ids, project_ids, cost_source, approvers, start_budget, params)
                                  .fetch(:winners)
    current_cost = mes.sum { |c| completion.float_cost(cost_source, c) }
    budget = completion.parse_number(start_budget)
    loop do
      if params.add1_option?("exhaustive")
        exhaustive = project_ids.none? do |extra|
          !mes.include?(extra) && current_cost + completion.float_cost(cost_source, extra) <= b
        end
        break if exhaustive
      end

      next_budget = budget + (n * params.increment)
      next_mes = Equalshares::FixedBudget.run(voter_ids, project_ids, cost_source, approvers, next_budget, params)
                                         .fetch(:winners)
      current_cost = next_mes.sum { |c| completion.float_cost(cost_source, c) }
      break unless current_cost <= b

      budget = next_budget
      mes = next_mes
    end

    Equalshares::FixedBudget.run(voter_ids, project_ids, cost_source, approvers, budget, params, report_details: true)
  end
end
