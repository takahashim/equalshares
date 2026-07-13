# frozen_string_literal: true

module Equalshares
  # Dinic's maximum-flow algorithm with integer capacities. Used by the maximin
  # support rule to compute the exact minimum max-load (a max-density subgraph) via
  # a parametric max-flow, keeping the gem pure-Ruby and dependency-free.
  class MaxFlow
    def initialize(num_nodes)
      @num_nodes = num_nodes
      @graph = Array.new(num_nodes) { [] } # node -> array of edges [to, cap, rev_index]
    end

    def add_edge(from, to, cap)
      @graph[from] << [to, cap, @graph[to].size]
      @graph[to] << [from, 0, @graph[from].size - 1]
    end

    def max_flow(source, sink)
      flow = 0
      while build_levels(source, sink)
        @iter = Array.new(@num_nodes, 0)
        while (pushed = augment(source, sink, Float::INFINITY)).positive?
          flow += pushed
        end
      end
      flow
    end

    # Nodes reachable from `source` in the residual graph (the source side of a
    # minimum cut after max_flow has run).
    def reachable_from(source)
      visited = Array.new(@num_nodes, false)
      visited[source] = true
      queue = [source]
      until queue.empty?
        node = queue.shift
        @graph[node].each do |edge|
          to, cap, = edge
          next unless cap.positive? && !visited[to]

          visited[to] = true
          queue << to
        end
      end
      visited
    end

    private

    # Builds the BFS level graph; returns whether the sink is reachable.
    def build_levels(source, sink) # rubocop:disable Naming/PredicateMethod
      @level = Array.new(@num_nodes, -1)
      @level[source] = 0
      queue = [source]
      until queue.empty?
        node = queue.shift
        @graph[node].each do |edge|
          to, cap, = edge
          next unless cap.positive? && @level[to].negative?

          @level[to] = @level[node] + 1
          queue << to
        end
      end
      !@level[sink].negative?
    end

    # The level graph is at most a few layers deep (source-project-voter-sink), so
    # this recursion stays shallow.
    def augment(node, sink, limit)
      return limit if node == sink

      while @iter[node] < @graph[node].size
        edge = @graph[node][@iter[node]]
        to, cap = edge
        if cap.positive? && @level[node] < @level[to]
          delta = augment(to, sink, [limit, cap].min)
          if delta.positive?
            edge[1] -= delta
            @graph[to][edge[2]][1] += delta
            return delta
          end
        end
        @iter[node] += 1
      end
      0
    end
  end
end
