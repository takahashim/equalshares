# frozen_string_literal: true

require "optparse"

require_relative "cli/formatter"

module Equalshares
  # Command-line interface: parse a .pb file and print the Method of Equal Shares outcome.
  class CLI
    def self.start(argv)
      new.run(argv)
    end

    # Each rule name maps to a runner (instance, params, progress) -> Result.
    RULE_RUNNERS = {
      "mes" => ->(instance, params, progress) { Compute.equal_shares(instance, params, progress: progress) },
      "phragmen" => ->(instance, params, progress) { Phragmen.sequential(instance, params, progress: progress) },
      "greedy" => ->(instance, params, _progress) { Greedy.utilitarian_welfare(instance, params) },
      "maximin" => ->(instance, params, progress) { Maximin.support(instance, params, progress: progress) }
    }.freeze
    RULES = RULE_RUNNERS.keys.freeze

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
      result = RULE_RUNNERS.fetch(options[:rule]).call(instance, params, progress)
      warn "" if options[:progress]

      print Formatter.new(instance, result).render(options[:format])
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
  end
end
