# frozen_string_literal: true

module Equalshares
  # Facade for the maximin support rule; delegates to Rules::Maximin.
  module Maximin
    module_function

    def support(instance, params = Params.new, progress: nil)
      Rules::Maximin.call(instance, params, progress: progress)
    end
  end
end
