# frozen_string_literal: true

require_relative "equalshares/version"
require_relative "equalshares/errors"
require_relative "equalshares/instance"
require_relative "equalshares/satisfaction"
require_relative "equalshares/params"
require_relative "equalshares/pabulib"
require_relative "equalshares/tie_breaking"
require_relative "equalshares/statistics"
require_relative "equalshares/election"
require_relative "equalshares/fixed_budget"
require_relative "equalshares/completion"
require_relative "equalshares/comparison"
require_relative "equalshares/max_flow"

# Rule objects
require_relative "equalshares/rules/base"
require_relative "equalshares/rules/method_of_equal_shares"
require_relative "equalshares/rules/cardinal_mes"
require_relative "equalshares/rules/phragmen"
require_relative "equalshares/rules/greedy"
require_relative "equalshares/rules/maximin"

# Facades over the rule objects (stable public API)
require_relative "equalshares/phragmen"
require_relative "equalshares/greedy"
require_relative "equalshares/maximin"
require_relative "equalshares/mes_general"
require_relative "equalshares/compute"

module Equalshares
  # Convenience: parse a .pb file and compute the outcome in one call.
  def self.compute_file(path, params = Params.new, progress: nil)
    instance = Pabulib.parse_file(path)
    Compute.equal_shares(instance, params, progress: progress)
  end
end
