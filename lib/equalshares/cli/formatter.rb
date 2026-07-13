# frozen_string_literal: true

require "json"
require "csv"

module Equalshares
  class CLI
    # Renders a computation Result for a given instance as human-readable text, CSV or
    # JSON. Each renderer returns a String (including the trailing newline).
    class Formatter
      def initialize(instance, result)
        @instance = instance
        @result = result
      end

      def render(format)
        case format
        when "json" then json
        when "csv" then csv
        else human
        end
      end

      def json
        "#{JSON.pretty_generate(@result.to_h)}\n"
      end

      def csv
        CSV.generate do |csv|
          csv << %w[project_id name cost votes effective_vote_count]
          @result.winners.each do |c|
            csv << [c, project(c, "name"), project(c, "cost"),
                    @instance.approvers[c].length, @result.effective_vote_count(c)]
          end
        end
      end

      def human
        lines = summary_lines + [""]
        rows = @result.winners.map do |c|
          [c, truncate(project(c, "name"), 50), project(c, "cost"),
           @instance.approvers[c].length.to_s, format_number(@result.effective_vote_count(c))]
        end
        "#{(lines + table(%w[id name cost votes eff.votes], rows)).join("\n")}\n"
      end

      private

      def project(project_id, field)
        @instance.projects[project_id][field]
      end

      def summary_lines
        lines = ["Winners: #{@result.winners.length} projects, " \
                 "total cost #{format_number(@result.total_cost)} of budget #{@instance.budget}"]
        lines << "Voter endowment: #{format_number(@result.endowment)}" if @result.endowment
        lines << "Avg. approved winning projects per voter: #{@result.stats[:avg_approved_projects].round(3)}"
        lines << "Computation time: #{@result.time}s"
      end

      def table(headers, rows)
        widths = headers.each_index.map do |i|
          ([headers[i]] + rows.map { |r| r[i].to_s }).map(&:length).max
        end
        line = ->(cells) { cells.each_index.map { |i| cells[i].to_s.ljust(widths[i]) }.join("  ") }
        [line.call(headers), widths.map { |w| "-" * w }.join("  ")] + rows.map { |r| line.call(r) }
      end

      def truncate(str, max)
        str.to_s.length > max ? "#{str[0, max - 1]}…" : str.to_s
      end

      def format_number(value)
        f = value.to_f
        f == f.round ? f.round.to_s : f.round(2).to_s
      end
    end
  end
end
