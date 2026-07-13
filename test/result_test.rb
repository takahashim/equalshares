# frozen_string_literal: true

require_relative "test_helper"

class ResultTest < Minitest::Test
  include TestSupport

  def compute
    Equalshares::Compute.equal_shares(sample_instance, Equalshares::Params.new(completion: "none"))
  end

  def test_reader_methods
    result = compute
    assert_kind_of Equalshares::Result, result
    assert_kind_of Array, result.winners
    assert_equal result.stats[:total_cost], result.total_cost
    assert_match(/\A\d+\.\d\z/, result.time)
    refute_nil result.endowment
  end

  def test_to_h
    result = compute
    assert_equal({ winners: result.winners, notes: result.notes }, result.to_h)
  end

  def test_effective_vote_count_and_json
    result = compute
    winner = result.winners.first
    assert_operator result.effective_vote_count(winner), :>, 0
    assert_nil result.effective_vote_count("does-not-exist")
    assert_kind_of String, result.to_json
  end
end
