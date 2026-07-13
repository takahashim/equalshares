# frozen_string_literal: true

module Equalshares
  # Facade for the Method of Equal Shares on cardinal/ordinal ballots; delegates to
  # Rules::CardinalMes.
  module MesGeneral
    module_function

    def equal_shares(instance, params = Params.new, progress: nil)
      Rules::CardinalMes.call(instance, params, progress: progress)
    end
  end
end
