# frozen_string_literal: true

module Equalshares
  # Voting rules as objects. Each concrete rule is a Rules::Base subclass that computes
  # winners from an instance; the thin module facades (Equalshares::Phragmen, etc.)
  # delegate to these classes.
  module Rules
    # Holds the (instance, params) and the derived Election numeric view, and assembles
    # the { winners:, notes: } result with statistics and timing. Subclasses implement
    # #call and return `result(winners, start, extra_notes)`.
    class Base
      def self.call(instance, params = Params.new, progress: nil)
        new(instance, params, progress: progress).call
      end

      def initialize(instance, params = Params.new, progress: nil)
        @instance = instance
        @params = params
        @progress = progress
        @election = Election.new(instance, params)
      end

      def call
        raise NotImplementedError, "#{self.class} must implement #call"
      end

      private

      attr_reader :instance, :params, :election, :progress

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Build the Result, adding outcome statistics and elapsed time to any
      # rule-specific notes.
      def result(winners, since, extra_notes = {})
        notes = extra_notes.merge(stats: election.statistics(winners),
                                  time: format("%.1f", now - since))
        Result.new(winners: winners, notes: notes)
      end
    end
  end
end
