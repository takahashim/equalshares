# frozen_string_literal: true

require_relative "test_helper"

class TieBreakerTest < Minitest::Test
  COST = { "a" => 10, "b" => 5, "c" => 5 }.freeze
  APPROVERS = { "a" => [1, 2], "b" => [1], "c" => [1, 2, 3] }.freeze
  PROJECT_IDS = %w[a b c].freeze

  def break_ties(tie_breaking, choices)
    params = Equalshares::Params.new(tie_breaking: tie_breaking)
    Equalshares::Tie.break_ties(PROJECT_IDS, COST, APPROVERS, params, choices)
  end

  def test_max_votes_keeps_highest_approver_count
    assert_equal ["c"], break_ties(["maxVotes"], %w[a b c])
  end

  def test_min_and_max_cost
    assert_equal %w[b c], break_ties(["minCost"], %w[a b c])
    assert_equal ["a"], break_ties(["maxCost"], %w[a b c])
  end

  def test_chained_criteria_narrow_in_order
    # minCost keeps b,c; then maxVotes keeps c
    assert_equal ["c"], break_ties(%w[minCost maxVotes], %w[a b c])
  end

  def test_lexico_respects_list_order
    order = %w[c a b]
    # among {a, b}, "a" comes first in the list regardless of choices order
    assert_equal ["a"], break_ties([{ lexico: order }], %w[b a])
    assert_equal ["a"], break_ties([{ lexico: order }], %w[a b])
  end

  def test_explicit_list_uses_choices_order_not_list_order
    order = %w[c a b]
    # JS-faithful: first *choice* that is in the list, so choices order wins
    assert_equal ["b"], break_ties([order], %w[b a])
    assert_equal ["a"], break_ties([order], %w[a b])
  end

  def test_total_order_ranks_by_strategy_then_original_order
    params = Equalshares::Params.new(tie_breaking: ["maxVotes"])
    # descending approver count: c(3), a(2), b(1)
    assert_equal %w[c a b], Equalshares::Tie.total_order(PROJECT_IDS, COST, APPROVERS, params)
  end
end
