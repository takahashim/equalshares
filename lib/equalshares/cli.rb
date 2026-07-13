# frozen_string_literal: true

require "optparse"
require "json"
require "csv"

module Equalshares
  # Command-line interface: parse a .pb file and print the Method of Equal Shares outcome.
  class CLI
    def self.start(argv)
      new.run(argv)
    end

    RULES = %w[mes phragmen greedy maximin].freeze

    def run(argv)
      options = { format: "human", progress: false, rule: "mes" }
      param_opts = {}
      parser = build_parser(options, param_opts)
      files = parser.parse(argv)

      if files.length != 1
        warn parser.help
        return 2
      end

      params = Params.new(**param_opts)
      progress = options[:progress] ? ->(pct) { warn "\rComputing... #{pct}%" } : nil

      instance = Pabulib.parse_file(files.first)
      result =
        case options[:rule]
        when "phragmen" then Phragmen.sequential(instance, params, progress: progress)
        when "greedy" then Greedy.utilitarian_welfare(instance, params)
        when "maximin" then Maximin.support(instance, params, progress: progress)
        else Compute.equal_shares(instance, params, progress: progress)
        end
      warn "" if options[:progress]

      emit(options[:format], instance, result)
      0
    rescue OptionParser::ParseError => e
      warn "Error: #{e.message}"
      2
    rescue ParseError, ComputeError, Errno::ENOENT => e
      warn "Error: #{e.message}"
      1
    end

    private

    def build_parser(options, param_opts)
      OptionParser.new do |o|
        o.banner = "Usage: equalshares [options] FILE.pb"
        o.separator ""
        o.separator "Computation options:"
        o.on("--rule NAME", RULES, "Voting rule: mes (default), phragmen, greedy, maximin") do |v|
          options[:rule] = v
        end
        o.on("--completion NAME", Params::COMPLETIONS, "Completion method (default: add1u)") do |v|
          param_opts[:completion] = v
        end
        o.on("--accuracy NAME", Params::ACCURACIES, "floats (default) or fractions") do |v|
          param_opts[:accuracy] = v
        end
        o.on("--satisfaction NAME", Params::SATISFACTIONS,
             "MES satisfaction: cost (default), cardinality, effort") do |v|
          param_opts[:satisfaction] = v
        end
        o.on("--tie-breaking LIST", Array, "Comma-separated: maxVotes,minCost,maxCost") do |v|
          param_opts[:tie_breaking] = v
        end
        o.on("--add1-options LIST", Array, "Comma-separated: exhaustive,integral") do |v|
          param_opts[:add1_options] = v
        end
        o.on("--comparison NAME", Params::COMPARISONS, "none (default), satisfaction, exclusionRatio") do |v|
          param_opts[:comparison] = v
        end
        o.on("--increment N", Integer, "Budget increment for Add1 (default: 1)") do |v|
          param_opts[:increment] = v
        end
        o.separator ""
        o.separator "Output options:"
        o.on("--format FMT", %w[human csv json], "human (default), csv, or json") do |v|
          options[:format] = v
        end
        o.on("--progress", "Show computation progress on stderr") { options[:progress] = true }
        o.on("-h", "--help", "Show this help") do
          puts o
          exit 0
        end
        o.on("-v", "--version", "Show version") do
          puts Equalshares::VERSION
          exit 0
        end
      end
    end

    def emit(format, instance, result)
      case format
      when "json" then emit_json(result)
      when "csv"  then emit_csv(instance, result)
      else             emit_human(instance, result)
      end
    end

    def emit_json(result)
      puts JSON.pretty_generate(result.to_h)
    end

    def emit_csv(instance, result)
      out = CSV.generate do |csv|
        csv << %w[project_id name cost votes effective_vote_count]
        result.winners.each do |c|
          csv << [c, instance.projects[c]["name"], instance.projects[c]["cost"],
                  instance.approvers[c].length, result.effective_vote_count(c)]
        end
      end
      print out
    end

    def emit_human(instance, result)
      stats = result.stats
      winners = result.winners
      puts "Winners: #{winners.length} projects, total cost #{format_number(result.total_cost)} " \
           "of budget #{instance.budget}"
      puts "Voter endowment: #{format_number(result.endowment)}" if result.endowment
      puts "Avg. approved winning projects per voter: #{stats[:avg_approved_projects].round(3)}"
      puts "Computation time: #{result.time}s"
      puts

      rows = winners.map do |c|
        [c, truncate(instance.projects[c]["name"], 50), instance.projects[c]["cost"],
         instance.approvers[c].length.to_s, format_number(result.effective_vote_count(c))]
      end
      print_table(%w[id name cost votes eff.votes], rows)
    end

    def print_table(headers, rows)
      widths = headers.each_index.map do |i|
        ([headers[i]] + rows.map { |r| r[i].to_s }).map(&:length).max
      end
      line = ->(cells) { cells.each_index.map { |i| cells[i].to_s.ljust(widths[i]) }.join("  ") }
      puts line.call(headers)
      puts widths.map { |w| "-" * w }.join("  ")
      rows.each { |r| puts line.call(r) }
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
