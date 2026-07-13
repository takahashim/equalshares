# frozen_string_literal: true

require_relative "test_helper"

class PabulibTest < Minitest::Test
  include TestSupport

  def test_parses_sample_instance
    inst = sample_instance
    assert_equal 64, inst.project_ids.length
    assert_equal 6586, inst.voter_ids.length
    assert_equal "1000000", inst.budget
    assert_equal "approval", inst.meta["vote_type"]
  end

  def test_builds_approvers_index
    inst = sample_instance
    # project 24 has 720 votes per the PROJECTS section
    assert_equal 720, inst.approvers["24"].length
  end

  def test_name_falls_back_to_project_id_when_missing
    text = <<~PB
      META
      key;value
      budget;100
      PROJECTS
      project_id;cost
      p1;40
      VOTES
      voter_id;vote
      v1;p1
    PB
    inst = Equalshares::Pabulib.parse_from_string(text)
    assert_equal "p1", inst.projects["p1"]["name"]
  end

  def test_quoted_field_with_semicolon
    text = <<~PB
      META
      key;value
      budget;100
      PROJECTS
      project_id;cost;name
      p1;40;"Park; with semicolon"
      VOTES
      voter_id;vote
      v1;p1
    PB
    inst = Equalshares::Pabulib.parse_from_string(text)
    assert_equal "Park; with semicolon", inst.projects["p1"]["name"]
  end

  def test_missing_section_raises
    text = "META\nkey;value\nbudget;100\nPROJECTS\nproject_id;cost\np1;40\n"
    err = assert_raises(Equalshares::ParseError) { Equalshares::Pabulib.parse_from_string(text) }
    assert_match(/missing the required 'votes' section/, err.message)
  end

  def test_duplicate_project_id_raises
    text = "META\nkey;value\nbudget;100\nPROJECTS\nproject_id;cost\np1;40\np1;50\nVOTES\nvoter_id;vote\nv1;p1\n"
    assert_raises(Equalshares::ParseError) { Equalshares::Pabulib.parse_from_string(text) }
  end

  def test_non_numeric_budget_raises
    text = "META\nkey;value\nbudget;abc\nPROJECTS\nproject_id;cost\np1;40\nVOTES\nvoter_id;vote\nv1;p1\n"
    assert_raises(Equalshares::ParseError) { Equalshares::Pabulib.parse_from_string(text) }
  end

  def test_invalid_project_id_in_vote_raises
    text = "META\nkey;value\nbudget;100\nPROJECTS\nproject_id;cost\np1;40\nVOTES\nvoter_id;vote\nv1;p9\n"
    assert_raises(Equalshares::ParseError) { Equalshares::Pabulib.parse_from_string(text) }
  end

  def test_short_project_row_raises_parse_error_not_no_method_error
    # project_id is not the first column, and the row is missing it entirely.
    text = "META\nkey;value\nbudget;100\nPROJECTS\ncost;project_id\n40\nVOTES\nvoter_id;vote\nv1;\n"
    err = assert_raises(Equalshares::ParseError) { Equalshares::Pabulib.parse_from_string(text) }
    assert_match(/Invalid number of columns/, err.message)
  end

  def test_write_string_round_trips
    Dir[File.join(TestSupport::REPO_ROOT, "test/fixtures/pb/*.pb")].each do |path|
      original = Equalshares::Pabulib.parse_file(path)
      reparsed = Equalshares::Pabulib.parse_from_string(Equalshares::Pabulib.write_string(original))
      assert_equal original.meta, reparsed.meta, "meta differs for #{File.basename(path)}"
      assert_equal original.projects, reparsed.projects, "projects differ for #{File.basename(path)}"
      assert_equal original.votes, reparsed.votes, "votes differ for #{File.basename(path)}"
      assert_equal original.approvers, reparsed.approvers, "approvers differ for #{File.basename(path)}"
    end
  end

  def test_write_string_quotes_fields_with_semicolons
    text = <<~PB
      META
      key;value
      budget;100
      PROJECTS
      project_id;cost;name
      p1;40;"A; B"
      VOTES
      voter_id;vote
      v1;p1
    PB
    out = Equalshares::Pabulib.write_string(Equalshares::Pabulib.parse_from_string(text))
    assert_includes out, '"A; B"'
  end
end
