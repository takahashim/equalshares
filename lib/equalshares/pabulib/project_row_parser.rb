# frozen_string_literal: true

module Equalshares
  module Pabulib
    # Parses a single row of the PROJECTS section into the accumulator.
    class ProjectRowParser
      def initialize(accumulator)
        @acc = accumulator
      end

      def parse(row, header, line_number)
        project_id_idx = header.index("project_id")
        cost_idx = header.index("cost")
        name_idx = header.index("name")

        require_columns!(project_id_idx, cost_idx, line_number)
        # Validate the column count before any indexed access, so a short row raises a
        # ParseError rather than a NoMethodError on nil.
        validate_column_count!(row, header, line_number)

        project_id = row[project_id_idx].strip
        if @acc.project_ids_set[project_id]
          raise ParseError, "Line #{line_number}: Duplicate project ID '#{project_id}' found."
        end
        if row[project_id_idx].to_s.empty? || !Csv.numeric_string?(row[cost_idx])
          raise ParseError, "Line #{line_number}: Invalid or missing values in projects section."
        end

        store(row, header, project_id, name_idx)
      end

      private

      def require_columns!(project_id_idx, cost_idx, line_number)
        return unless project_id_idx.nil? || cost_idx.nil?

        missing = []
        missing << "project_id " if project_id_idx.nil?
        missing << "cost" if cost_idx.nil?
        raise ParseError, "Line #{line_number}: Missing required column(s) in projects section: #{missing.join}."
      end

      def validate_column_count!(row, header, line_number)
        return if row.length == header.length

        raise ParseError, "Line #{line_number}: Invalid number of columns in projects section."
      end

      def store(row, header, project_id, name_idx)
        @acc.project_ids_set[project_id] = true
        @acc.projects[project_id] = {}
        @acc.approvers[project_id] = []
        header.each_index { |idx| @acc.projects[project_id][header[idx].strip] = row[idx].strip }

        name = @acc.projects[project_id]["name"]
        @acc.projects[project_id]["name"] = project_id if name_idx.nil? || name.nil? || name.strip.empty?
      end
    end
  end
end
