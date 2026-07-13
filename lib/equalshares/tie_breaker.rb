# frozen_string_literal: true

module Equalshares
  # Tie-breaking strategies. Each element of params.tie_breaking maps to one strategy
  # object (via TieBreaker.for). A strategy can either narrow a tied set (#filter, used
  # to resolve a single tie in priority order) or contribute a sort key (#sort_key, used
  # to build a total order over all projects). Mirrors pabutools' TieBreakingRule.
  module TieBreaker
    # Cost/approver lookups a strategy needs. `cost` is the rule's numeric cost map.
    Context = Struct.new(:cost, :approvers)

    module_function

    def for(method)
      case method
      when "maxVotes" then MaxVotes.new
      when "minCost" then MinCost.new
      when "maxCost" then MaxCost.new
      when Hash then Lexico.new(lexico_order(method))
      when Array then ExplicitList.new(method)
      else
        raise ComputeError, "Unknown tie-breaking method: #{method}"
      end
    end

    def lexico_order(method)
      order = method[:lexico] || method["lexico"]
      raise ComputeError, "Unknown tie-breaking method: #{method}" unless order.is_a?(Array)

      order
    end

    # Keep the projects tied at the best value of some key.
    class Extreme
      def filter(remaining, ctx)
        best = remaining.map { |c| key(c, ctx) }.public_send(extreme)
        remaining.select { |c| key(c, ctx) == best }
      end
    end

    class MaxVotes < Extreme
      def key(project_id, ctx) = ctx.approvers[project_id].length
      def extreme = :max
      def sort_key(project_id, ctx) = -ctx.approvers[project_id].length
    end

    class MinCost < Extreme
      def key(project_id, ctx) = ctx.cost[project_id]
      def extreme = :min
      def sort_key(project_id, ctx) = ctx.cost[project_id]
    end

    class MaxCost < Extreme
      def key(project_id, ctx) = ctx.cost[project_id]
      def extreme = :max
      def sort_key(project_id, ctx) = -ctx.cost[project_id]
    end

    # A total order (pabutools-style): rank tied projects by their position in the list
    # and keep the first.
    class Lexico
      def initialize(order)
        @order = order
        @position = order.each_with_index.to_h
      end

      def filter(remaining, _ctx)
        [remaining.min_by { |c| @position[c] || @order.length }]
      end

      def sort_key(project_id, _ctx)
        @position[project_id] || @order.length
      end
    end

    # JS-faithful explicit list: keep the first *choice* that appears anywhere in the
    # list (does NOT respect the list's ordering). Kept for bit-compatibility with the
    # equalshares.net tool; prefer Lexico for an order-respecting tie-break.
    class ExplicitList
      def initialize(list)
        @list = list
        @position = list.each_with_index.to_h
      end

      def filter(remaining, _ctx)
        found = remaining.find { |c| @list.include?(c) }
        found ? [found] : remaining
      end

      def sort_key(project_id, _ctx)
        @position[project_id] || @list.length
      end
    end
  end
end
