# frozen_string_literal: true

module Equalshares
  # A parsed pabulib instance.
  #
  # Mirrors the JS `{ meta, projects, votes, approvers }` shape:
  #   meta      - Hash{String => String} key/value metadata (includes "budget", "vote_type")
  #   projects  - Hash{String => Hash{String => String}} project_id => raw row fields (incl "cost", "name")
  #   votes     - Hash{String => Hash{String => String}} voter_id => raw row fields
  #   approvers - Hash{String => Array<String>} project_id => list of voter_ids approving it
  class Instance
    attr_reader :meta, :projects, :votes, :approvers, :scores

    # `scores` is nil for approval instances; for cardinal ballots (vote_type
    # "scoring"/"cumulative") it is Hash{project_id => Hash{voter_id => score string}}.
    def initialize(meta:, projects:, votes:, approvers:, scores: nil)
      @meta = meta
      @projects = projects
      @votes = votes
      @approvers = approvers
      @scores = scores
    end

    # True for cardinal (scoring/cumulative) instances that carry per-voter scores.
    def cardinal?
      !@scores.nil?
    end

    def vote_type
      @meta["vote_type"]
    end

    # Voter IDs (JS: Object.keys(votes))
    def voter_ids
      @voter_ids ||= self.class.js_key_order(@votes.keys)
    end

    # Project IDs (JS: Object.keys(projects))
    def project_ids
      @project_ids ||= self.class.js_key_order(@projects.keys)
    end

    def budget
      @meta["budget"]
    end

    # Replicate the iteration order of JavaScript's Object.keys, which the original
    # tool relies on (C = Object.keys(projects), N = Object.keys(votes)): integer
    # "array index" keys come first in ascending numeric order, followed by all
    # other keys in insertion order. Project/voter IDs are typically numeric strings,
    # so this ordering affects tie stability (e.g. greedy utilitarian completion).
    ARRAY_INDEX = /\A(?:0|[1-9]\d*)\z/
    UINT32_MAX = (2**32) - 1

    def self.js_key_order(keys)
      indices, others = keys.partition { |k| ARRAY_INDEX.match?(k) && k.to_i < UINT32_MAX }
      indices.sort_by(&:to_i) + others
    end
  end
end
