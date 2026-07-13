# frozen_string_literal: true

module Equalshares
  # Facade for Phragmén's sequential rule; delegates to Rules::Phragmen.
  module Phragmen
    module_function

    def sequential(instance, params = Params.new, progress: nil)
      Rules::Phragmen.call(instance, params, progress: progress)
    end
  end
end
