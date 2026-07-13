# frozen_string_literal: true

module Equalshares
  module Pabulib
    # Low-level lexing shared by the parser: the ';'-delimited, double-quote-escaped
    # field splitter (port of parseCSVLine in js/pabulibParser.js) and the JS-style
    # numeric check.
    module Csv
      module_function

      def parse_line(line)
        result = []
        current = +""
        in_quotes = false
        i = 0

        while i < line.length
          char = line[i]
          if char == '"'
            if in_quotes && i + 1 < line.length && line[i + 1] == '"'
              current << '"'
              i += 2
            else
              in_quotes = !in_quotes
              i += 1
            end
          elsif char == ";" && !in_quotes
            result << current
            current = +""
            i += 1
          else
            current << char
            i += 1
          end
        end

        result << current
        result
      end

      # Whether a string parses as a number the way JavaScript's Number() does: empty
      # or whitespace-only strings count as numeric (they coerce to 0), nil does not.
      def numeric_string?(value)
        return false if value.nil?

        str = value.strip
        return true if str.empty?

        Float(str)
        true
      rescue ArgumentError, TypeError
        false
      end
    end
  end
end
