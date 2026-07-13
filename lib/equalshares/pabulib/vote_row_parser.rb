# frozen_string_literal: true

module Equalshares
  module Pabulib
    # Parses a single row of the VOTES section into the accumulator, turning the vote
    # into approvals and (for scoring/cumulative/ordinal ballots) per-voter scores.
    class VoteRowParser
      def initialize(accumulator)
        @acc = accumulator
        vote_type = accumulator.meta["vote_type"]
        @cardinal = CARDINAL_VOTE_TYPES.include?(vote_type)
        @ordinal = vote_type == "ordinal"
      end

      def parse(row, header, line_number)
        voter_id_idx = header.index("voter_id")
        vote_idx = header.index("vote")
        points_idx = header.index("points")

        require_columns!(voter_id_idx, vote_idx, line_number)
        validate_column_count!(row, header, line_number)

        voter_id = row[voter_id_idx].strip
        raise ParseError, "Line #{line_number}: Duplicate voter ID '#{voter_id}' found." if @acc.voter_ids_set[voter_id]

        record_vote(row, vote_idx, points_idx, voter_id, line_number)
        store_voter(row, header, voter_id)
      end

      private

      def require_columns!(voter_id_idx, vote_idx, line_number)
        return unless voter_id_idx.nil? || vote_idx.nil?

        missing = []
        missing << "voter_id " if voter_id_idx.nil?
        missing << "vote" if vote_idx.nil?
        raise ParseError, "Line #{line_number}: Missing required column(s) in votes section: #{missing.join}."
      end

      def validate_column_count!(row, header, line_number)
        return if row.length == header.length

        raise ParseError, "Line #{line_number}: Invalid number of columns in votes section."
      end

      def record_vote(row, vote_idx, points_idx, voter_id, line_number)
        return if row[vote_idx] == ""

        project_list = row[vote_idx].split(",")
        points = points_list(row, points_idx)
        project_list.each_with_index do |project_id, k|
          pid = project_id.strip
          unless @acc.project_ids_set[pid]
            raise ParseError, "Line #{line_number}: Invalid project ID '#{pid}' found in vote."
          end

          add_support(pid, voter_id, score_for(project_list, points, k))
        end
      end

      def points_list(row, points_idx)
        return nil unless @cardinal && points_idx && row[points_idx] != ""

        row[points_idx].split(",")
      end

      # Borda score for ordinal ballots (ballot length - rank - 1, last-ranked = 0);
      # the raw points value for scoring/cumulative ballots; nil for plain approval.
      def score_for(project_list, points, index)
        if @ordinal
          (project_list.length - index - 1).to_s
        elsif points
          points[index].to_s.strip
        end
      end

      def add_support(pid, voter_id, score)
        if @ordinal || score
          return unless Float(score, exception: false)&.positive? # supporters have a positive score

          @acc.approvers[pid] << voter_id
          (@acc.scores[pid] ||= {})[voter_id] = score
        else
          @acc.approvers[pid] << voter_id
        end
      end

      def store_voter(row, header, voter_id)
        @acc.voter_ids_set[voter_id] = true
        @acc.votes[voter_id] = {}
        header.each_index { |idx| @acc.votes[voter_id][header[idx].strip] = row[idx].strip }
      end
    end
  end
end
