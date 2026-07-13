# frozen_string_literal: true

require_relative "test_helper"

# Regression over several real pabulib instances (subsampled fixtures in
# test/fixtures/pb/, from Poland, the Netherlands and Hungary — different
# currencies, column layouts and sizes). Each (fixture, params) case is checked
# against the original JavaScript implementation (test/fixtures/pb_reference.json,
# regenerated with test/fixtures/generate_pb_reference.js). Success cases must yield
# identical winners and matching statistics; cases where the JS throws (e.g. an
# unbroken tie) must also raise in Ruby.
class PbRegressionTest < Minitest::Test
  include TestSupport

  PB_REFERENCE = File.join(__dir__, "fixtures", "pb_reference.json")

  def pb_reference
    @pb_reference ||= JSON.parse(File.read(PB_REFERENCE))
  end

  def instance_for(fixture)
    Equalshares::Pabulib.parse_file(File.join(__dir__, "fixtures", "pb", fixture))
  end

  def test_reference_has_cases
    refute_empty pb_reference, "pb_reference.json should not be empty"
  end

  def test_matches_js_reference_per_fixture
    pb_reference.each do |key, data|
      params = params_from_reference(data["params"])

      if data.key?("error")
        assert_raises(Equalshares::ComputeError, "expected #{key} to raise") do
          Equalshares::Compute.equal_shares(instance_for(data["fixture"]), params)
        end
        next
      end

      result = Equalshares::Compute.equal_shares(instance_for(data["fixture"]), params)
      expected = data["result"]

      assert_equal expected["winners"], result[:winners], "winners mismatch for #{key}"

      stats = result[:notes][:stats]
      assert_in_delta expected["totalCost"], stats[:total_cost].to_f, 1e-4, "total_cost #{key}"
      assert_in_delta expected["avgApprovedProjects"], stats[:avg_approved_projects].to_f, 1e-9, "avg #{key}"
      assert_in_delta expected["endowment"], result[:notes][:endowment].to_f, 1e-6, "endowment #{key}"

      expected["utilityDistribution"].each do |util, count|
        assert_equal count, stats[:utility_distribution][util.to_i], "utility[#{util}] #{key}"
      end
    end
  end
end
