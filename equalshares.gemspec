# frozen_string_literal: true

require_relative "lib/equalshares/version"

Gem::Specification.new do |spec|
  spec.name = "equalshares"
  spec.version = Equalshares::VERSION
  spec.authors = ["takahashim"]
  spec.email = ["takahashimm@gmail.com"]

  spec.summary = "Method of Equal Shares computation for participatory budgeting"
  spec.description = "A Ruby implementation of the equalshares.net compute tool. Parses pabulib (.pb) " \
                     "files and computes winning projects using the Method of Equal Shares (with " \
                     "tie-breaking, Add1/utilitarian completion and a comparison step), plus Phragmén's " \
                     "sequential rule, greedy utilitarian welfare and maximin support. Supports approval, " \
                     "cardinal (scoring/cumulative) and ordinal ballots, several satisfaction measures, and " \
                     "both exact (Rational) and floating-point arithmetic. Cross-checked against pabutools."
  spec.homepage = "https://github.com/takahashim/equalshares"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Ship only the runtime files; tests, fixtures and dev tooling are excluded.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ sig/ Gemfile Rakefile .gitignore .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
