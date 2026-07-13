# frozen_string_literal: true

require "json"

module Equalshares
  # The outcome of a voting rule: the winning project ids together with outcome
  # statistics, timing and any rule-specific notes (endowment, effective vote counts,
  # comparison message, greedy statistics, ...).
  class Result
    attr_reader :winners, :notes

    def initialize(winners:, notes:)
      @winners = winners
      @notes = notes
    end

    def stats
      notes[:stats]
    end

    def time
      notes[:time]
    end

    def total_cost
      stats[:total_cost]
    end

    def endowment
      notes[:endowment]
    end

    # Last recorded effective vote count for a project (Method of Equal Shares only),
    # or nil for rules/projects without one.
    def effective_vote_count(project_id)
      (notes[:effective_vote_count] || {})[project_id]&.last
    end

    def to_h
      { winners: winners, notes: notes }
    end

    def to_json(*)
      to_h.to_json(*)
    end
  end
end
