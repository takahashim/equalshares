# frozen_string_literal: true

module Equalshares
  module Pabulib
    # Mutable bag of results filled in as the sections are read.
    Accumulator = Struct.new(:meta, :projects, :votes, :approvers, :scores,
                             :project_ids_set, :voter_ids_set, keyword_init: true)

    # Reads a pabulib (.pb) document: drives the META / PROJECTS / VOTES section state
    # machine and delegates each data row to the appropriate row parser.
    class Parser
      def parse(text)
        @acc = Accumulator.new(meta: {}, projects: {}, votes: {}, approvers: {}, scores: {},
                               project_ids_set: {}, voter_ids_set: {})
        @encountered = {}
        @section = ""
        @header = []
        @line_number = 0

        text.split("\n").each do |line|
          @line_number += 1
          handle_line(line) unless line.strip.empty?
        end

        finish
      end

      private

      def handle_line(line)
        row = Csv.parse_line(line)
        if section_header?(row)
          start_section(row)
        elsif @header.empty?
          read_header(row)
        else
          dispatch_row(row)
        end
      end

      def section_header?(row)
        SECTIONS.include?(row[0].strip.downcase)
      end

      def start_section(row)
        @section = row[0].strip.downcase
        @encountered[@section] = true
        @header = []
      end

      def read_header(row)
        @header = row.map(&:strip)
        return unless @section == "meta" && (@header[0] != "key" || @header[1] != "value")

        raise ParseError, "Line #{@line_number}: Invalid header in meta section (expecting \"key;value\")."
      end

      def dispatch_row(row)
        case @section
        when "meta"
          @acc.meta[row[0]] = row[1].strip
        when "projects"
          (@project_row_parser ||= ProjectRowParser.new(@acc)).parse(row, @header, @line_number)
        when "votes"
          (@vote_row_parser ||= VoteRowParser.new(@acc)).parse(row, @header, @line_number)
        end
      end

      def finish
        SECTIONS.each do |section_name|
          next if @encountered[section_name]

          raise ParseError, "The file is missing the required '#{section_name}' section."
        end
        unless Csv.numeric_string?(@acc.meta["budget"])
          raise ParseError, "The 'budget' in the meta section is not a numeric value."
        end

        scored = SCORED_VOTE_TYPES.include?(@acc.meta["vote_type"])
        Instance.new(meta: @acc.meta, projects: @acc.projects, votes: @acc.votes,
                     approvers: @acc.approvers, scores: scored ? @acc.scores : nil)
      end
    end
  end
end
