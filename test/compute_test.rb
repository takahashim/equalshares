# frozen_string_literal: true

require_relative "test_helper"

class ComputeTest < Minitest::Test
  include TestSupport

  # Regression against the original JS implementation: winners must match exactly,
  # and statistics must match within tolerance (see test/fixtures/js_reference.json,
  # regenerated with test/fixtures/generate_js_reference.js).
  def test_matches_js_reference
    js_reference.each do |name, data|
      params = params_from_reference(data["params"])
      result = Equalshares::Compute.equal_shares(sample_instance, params)
      expected = data["result"]

      assert_equal expected["winners"], result[:winners], "winners mismatch for #{name}"

      stats = result[:notes][:stats]
      assert_in_delta expected["totalCost"], stats[:total_cost].to_f, 1e-6, "total_cost #{name}"
      assert_in_delta expected["avgApprovedProjects"], stats[:avg_approved_projects].to_f, 1e-9, "avg #{name}"
      assert_in_delta expected["endowment"], result[:notes][:endowment].to_f, 1e-9, "endowment #{name}"

      expected["utilityDistribution"].each do |util, count|
        assert_equal count, stats[:utility_distribution][util.to_i], "utility[#{util}] #{name}"
      end
    end
  end

  # fractions and floats should agree on the winner set for this instance.
  def test_fractions_and_floats_agree
    %w[none add1 add1u utilitarian].each do |completion|
      floats = Equalshares::Compute.equal_shares(
        sample_instance, Equalshares::Params.new(completion: completion, accuracy: "floats")
      )
      fractions = Equalshares::Compute.equal_shares(
        sample_instance, Equalshares::Params.new(completion: completion, accuracy: "fractions")
      )
      assert_equal floats[:winners], fractions[:winners], "winner mismatch for completion=#{completion}"
    end
  end

  def test_reports_computation_time
    result = Equalshares::Compute.equal_shares(sample_instance, Equalshares::Params.new(completion: "none"))
    assert_match(/\A\d+\.\d\z/, result[:notes][:time])
  end

  def test_invalid_params_raise
    assert_raises(Equalshares::ComputeError) { Equalshares::Params.new(completion: "bogus") }
    assert_raises(Equalshares::ComputeError) { Equalshares::Params.new(accuracy: "double") }
    assert_raises(Equalshares::ComputeError) { Equalshares::Params.new(increment: 0) }
  end
end
