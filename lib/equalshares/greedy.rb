# frozen_string_literal: true

module Equalshares
  # Facade for greedy utilitarian welfare; delegates to Rules::Greedy.
  module Greedy
    module_function

    def utilitarian_welfare(instance, params = Params.new)
      Rules::Greedy.call(instance, params)
    end
  end
end
