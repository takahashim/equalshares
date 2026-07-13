# frozen_string_literal: true

require_relative "pabulib/csv"
require_relative "pabulib/project_row_parser"
require_relative "pabulib/vote_row_parser"
require_relative "pabulib/parser"
require_relative "pabulib/writer"

module Equalshares
  # Reads and writes pabulib (.pb) files: a sectioned, semicolon-delimited CSV with
  # META / PROJECTS / VOTES sections. Faithful port of js/pabulibParser.js, extended
  # to cardinal (scoring/cumulative) and ordinal ballots.
  #
  # This module is a thin facade; the work lives in Pabulib::Parser (which delegates
  # rows to Pabulib::ProjectRowParser / Pabulib::VoteRowParser) and Pabulib::Writer.
  module Pabulib
    module_function

    SECTIONS = %w[meta projects votes].freeze
    # vote_type values that carry per-voter cardinal scores (a `points` column).
    CARDINAL_VOTE_TYPES = %w[scoring cumulative].freeze
    # vote_type values that produce per-voter utilities (scores) for the general MES:
    # cardinal ballots plus ordinal ballots (via Borda scores).
    SCORED_VOTE_TYPES = %w[scoring cumulative ordinal].freeze

    def parse_file(path)
      parse_from_string(File.read(path))
    end

    # Returns an Equalshares::Instance.
    def parse_from_string(filetext)
      Parser.new.parse(filetext)
    end

    def write_string(instance)
      Writer.write_string(instance)
    end

    def write_file(instance, path)
      Writer.write_file(instance, path)
    end
  end
end
