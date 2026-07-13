# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "equalshares"
require "json"
require "minitest/autorun"

module TestSupport
  REPO_ROOT = File.expand_path("..", __dir__)
  SAMPLE_PB = File.join(__dir__, "fixtures", "poland_wieliczka_2023_green-budget.pb")
  JS_REFERENCE = File.join(__dir__, "fixtures", "js_reference.json")

  def sample_text
    @sample_text ||= File.read(SAMPLE_PB)
  end

  def sample_instance
    Equalshares::Pabulib.parse_from_string(sample_text)
  end

  def js_reference
    @js_reference ||= JSON.parse(File.read(JS_REFERENCE))
  end

  def params_from_reference(hash)
    Equalshares::Params.new(
      tie_breaking: hash["tieBreaking"],
      completion: hash["completion"],
      add1_options: hash["add1options"],
      comparison: hash["comparison"],
      accuracy: hash["accuracy"],
      increment: hash["increment"]
    )
  end
end
