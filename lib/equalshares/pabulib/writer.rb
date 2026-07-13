# frozen_string_literal: true

module Equalshares
  module Pabulib
    # Serialises an Instance back to pabulib (.pb) text. Inverse of the parser:
    # META / PROJECTS / VOTES sections, ';'-separated, with fields containing ';', '"'
    # or newlines quoted (and embedded '"' doubled). Parsing the result yields an
    # equivalent Instance (round-trip safe).
    module Writer
      module_function

      def write_string(instance)
        lines = ["META", "key;value"]
        instance.meta.each { |key, value| lines << "#{escape(key)};#{escape(value)}" }
        write_section(lines, "PROJECTS", instance.projects)
        write_section(lines, "VOTES", instance.votes)
        "#{lines.join("\n")}\n"
      end

      def write_file(instance, path)
        File.write(path, write_string(instance))
      end

      def write_section(lines, header_name, rows_by_id)
        lines << header_name
        return if rows_by_id.empty?

        header = rows_by_id.values.first.keys
        lines << header.map { |h| escape(h) }.join(";")
        rows_by_id.each_value do |row|
          lines << header.map { |h| escape(row[h]) }.join(";")
        end
      end

      # Inverse of the CSV field handling in Pabulib::Csv.parse_line.
      def escape(value)
        str = value.to_s
        return str unless str.match?(/[;"\n]/)

        %("#{str.gsub('"', '""')}")
      end
    end
  end
end
