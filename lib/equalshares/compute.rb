# frozen_string_literal: true

module Equalshares
  # Facade for the Method of Equal Shares. Delegates to the rule objects: cardinal
  # ballots (per-voter utilities) go to Rules::CardinalMes, approval ballots to
  # Rules::MethodOfEqualShares (with the equalshares.net completion/comparison steps).
  module Compute
    module_function

    # Returns { winners: Array<String>, notes: Hash }.
    def equal_shares(instance, params = Params.new, progress: nil)
      if instance.cardinal?
        Rules::CardinalMes.call(instance, params, progress: progress)
      else
        Rules::MethodOfEqualShares.call(instance, params, progress: progress)
      end
    end
  end
end
