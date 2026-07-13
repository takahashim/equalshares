# frozen_string_literal: true

module Equalshares
  # Parser for pabulib (.pb) files. Faithful port of js/pabulibParser.js.
  #
  # A .pb file is a sectioned, semicolon-delimited CSV with META / PROJECTS / VOTES
  # sections. Only approval votes are supported.
  module Pabulib
    module_function

    SECTIONS = %w[meta projects votes].freeze

    def parse_file(path)
      parse_from_string(File.read(path))
    end

    # Returns an Equalshares::Instance.
    # vote_type values that carry per-voter cardinal scores (a `points` column).
    CARDINAL_VOTE_TYPES = %w[scoring cumulative].freeze
    # vote_type values that produce per-voter utilities (scores) for the general MES:
    # cardinal ballots plus ordinal ballots (via Borda scores).
    SCORED_VOTE_TYPES = %w[scoring cumulative ordinal].freeze

    def parse_from_string(filetext)
      meta = {}
      projects = {}
      votes = {}
      approvers = {}
      scores = {} # project_id => { voter_id => score string } for cardinal ballots
      project_ids_set = {}
      voter_ids_set = {}
      encountered_sections = {}

      section = ""
      header = []
      line_number = 0

      filetext.split("\n").each do |line|
        line_number += 1
        next if line.strip.empty?

        row = parse_csv_line(line)

        if SECTIONS.include?(row[0].strip.downcase)
          section = row[0].strip.downcase
          encountered_sections[section] = true
          header = []
          next
        end

        if header.empty?
          header = row.map(&:strip)
          if section == "meta" && (header[0] != "key" || header[1] != "value")
            raise ParseError, "Line #{line_number}: Invalid header in meta section (expecting \"key;value\")."
          end

          next
        end

        case section
        when "meta"
          meta[row[0]] = row[1].strip
        when "projects"
          parse_project_row(row, header, line_number, projects, approvers, project_ids_set)
        when "votes"
          parse_vote_row(row, header, line_number, votes, approvers, voter_ids_set, project_ids_set,
                         meta["vote_type"], scores)
        end
      end

      SECTIONS.each do |section_name|
        unless encountered_sections[section_name]
          raise ParseError, "The file is missing the required '#{section_name}' section."
        end
      end

      raise ParseError, "The 'budget' in the meta section is not a numeric value." if js_nan?(meta["budget"])

      scored = SCORED_VOTE_TYPES.include?(meta["vote_type"])
      Instance.new(meta: meta, projects: projects, votes: votes, approvers: approvers,
                   scores: scored ? scores : nil)
    end

    # Serialise an Instance back to pabulib (.pb) text. Inverse of parse_from_string:
    # META / PROJECTS / VOTES sections, ';'-separated, with fields containing ';', '"'
    # or newlines quoted (and embedded '"' doubled). Parsing the result yields an
    # equivalent Instance (round-trip safe).
    def write_string(instance)
      lines = []

      lines << "META"
      lines << "key;value"
      instance.meta.each { |key, value| lines << "#{escape_csv_field(key)};#{escape_csv_field(value)}" }

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
      lines << header.map { |h| escape_csv_field(h) }.join(";")
      rows_by_id.each_value do |row|
        lines << header.map { |h| escape_csv_field(row[h]) }.join(";")
      end
    end

    # Inverse of parse_csv_line's field handling.
    def escape_csv_field(value)
      str = value.to_s
      return str unless str.match?(/[;"\n]/)

      %("#{str.gsub('"', '""')}")
    end

    # CSV parsing helper handling double-quote escaping and ';' separators.
    # Port of the inline parseCSVLine in pabulibParser.js.
    def parse_csv_line(line)
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

    def parse_project_row(row, header, line_number, projects, approvers, project_ids_set)
      project_id_idx = header.index("project_id")
      cost_idx = header.index("cost")
      name_idx = header.index("name")

      if project_id_idx.nil? || cost_idx.nil?
        missing = []
        missing << "project_id " if project_id_idx.nil?
        missing << "cost" if cost_idx.nil?
        raise ParseError, "Line #{line_number}: Missing required column(s) in projects section: #{missing.join}."
      end

      project_id = row[project_id_idx].strip
      if project_ids_set[project_id]
        raise ParseError,
              "Line #{line_number}: Duplicate project ID '#{project_id}' found."
      end

      if row[project_id_idx].to_s.empty? || js_nan?(row[cost_idx])
        raise ParseError, "Line #{line_number}: Invalid or missing values in projects section."
      end

      if row.length != header.length
        raise ParseError, "Line #{line_number}: Invalid number of columns in projects section."
      end

      project_ids_set[project_id] = true
      projects[project_id] = {}
      approvers[project_id] = []

      header.each_index { |idx| projects[project_id][header[idx].strip] = row[idx].strip }

      name = projects[project_id]["name"]
      projects[project_id]["name"] = project_id if name_idx.nil? || name.nil? || name.strip.empty?
    end

    def parse_vote_row(row, header, line_number, votes, approvers, voter_ids_set, project_ids_set,
                       vote_type, scores)
      voter_id_idx = header.index("voter_id")
      vote_idx = header.index("vote")
      points_idx = header.index("points")

      if voter_id_idx.nil? || vote_idx.nil?
        missing = []
        missing << "voter_id " if voter_id_idx.nil?
        missing << "vote" if vote_idx.nil?
        raise ParseError, "Line #{line_number}: Missing required column(s) in votes section: #{missing.join}."
      end

      if row.length != header.length
        raise ParseError, "Line #{line_number}: Invalid number of columns in votes section."
      end

      voter_id = row[voter_id_idx].strip
      raise ParseError, "Line #{line_number}: Duplicate voter ID '#{voter_id}' found." if voter_ids_set[voter_id]

      cardinal = CARDINAL_VOTE_TYPES.include?(vote_type)
      ordinal = vote_type == "ordinal"
      points = cardinal && points_idx && row[points_idx] != "" ? row[points_idx].split(",") : nil

      unless row[vote_idx] == ""
        project_list = row[vote_idx].split(",")
        project_list.each_with_index do |project_id, k|
          pid = project_id.strip
          unless project_ids_set[pid]
            raise ParseError,
                  "Line #{line_number}: Invalid project ID '#{pid}' found in vote."
          end

          score =
            if ordinal
              # Borda score: ballot length minus 0-based index minus 1 (last-ranked = 0).
              (project_list.length - k - 1).to_s
            elsif points
              points[k].to_s.strip
            end

          if ordinal || points
            next unless Float(score, exception: false)&.positive? # supporters have positive score

            approvers[pid] << voter_id
            (scores[pid] ||= {})[voter_id] = score
          else
            approvers[pid] << voter_id
          end
        end
      end

      voter_ids_set[voter_id] = true
      votes[voter_id] = {}
      header.each_index { |idx| votes[voter_id][header[idx].strip] = row[idx].strip }
    end

    # Mimics JavaScript's isNaN(string): coerces via Number(). Empty / whitespace-only
    # strings coerce to 0 (not NaN), matching the original parser's behaviour.
    def js_nan?(value)
      return true if value.nil?

      str = value.strip
      return false if str.empty?

      Float(str)
      false
    rescue ArgumentError, TypeError
      true
    end
  end
end
