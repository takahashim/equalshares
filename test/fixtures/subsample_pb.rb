# frozen_string_literal: true

# Build lightweight regression fixtures from full pabulib instances.
#
# Downloads a few real approval-ballot .pb files from pabulib.org and writes
# subsampled copies into test/fixtures/pb/. META and the entire PROJECTS section
# are kept verbatim; only the VOTES rows are thinned by a deterministic stride so
# each fixture keeps roughly TARGET_VOTERS voters. The result is still a valid,
# real-format pabulib file (long quoted names, extra columns, various currencies) —
# just small enough to commit. The regression truth for these fixtures is produced
# by the original JavaScript implementation (see generate_js_reference.js), so
# subsampling does not weaken the test: Ruby is checked against JS on the exact
# same bytes.
#
# Usage: ruby test/fixtures/subsample_pb.rb

require "open-uri"
require "fileutils"

TARGET_VOTERS = 400
OUT_DIR = File.join(__dir__, "pb")
BASE = "https://pabulib.org/download"

FILES = %w[
  Poland_Warszawa_2021_Bielany.pb
  Netherlands_Amsterdam_2022_West.pb
  Hungary_Budapest_2024.pb
].freeze

def subsample(text)
  lines = text.split("\n") # keeps any trailing \r inside each line, preserving CRLF
  votes_idx = lines.index { |l| l.strip.downcase == "votes" }
  raise "no VOTES section" unless votes_idx

  # header is the next non-empty line after the VOTES marker
  header_idx = ((votes_idx + 1)...lines.length).find { |i| !lines[i].strip.empty? }
  head = lines[0..header_idx]
  rows = lines[(header_idx + 1)..].reject { |l| l.strip.empty? }

  stride = [rows.length / TARGET_VOTERS, 1].max
  kept = rows.each_index.select { |i| (i % stride).zero? }.map { |i| rows[i] }

  # keep num_votes meta consistent with the thinned electorate
  head = head.map { |l| l.downcase.start_with?("num_votes;") ? "num_votes;#{kept.length}" : l }

  "#{(head + kept).join("\n")}\n"
end

FileUtils.mkdir_p(OUT_DIR)
FILES.each do |name|
  full = URI.open("#{BASE}/#{name}", &:read) # rubocop:disable Security/Open
  out = subsample(full)
  path = File.join(OUT_DIR, name.downcase)
  File.write(path, out)
  puts "wrote #{path} (#{out.bytesize} bytes, #{out.count("\n")} lines)"
end
