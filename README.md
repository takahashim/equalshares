# Equalshares

A Ruby implementation of the [equalshares.net](https://equalshares.net/tools/compute/)
compute tool for participatory budgeting. It parses [pabulib](http://pabulib.org/) `.pb`
files and computes winning projects using the **Method of Equal Shares** and related
rules.

This started as a faithful port of the vanilla-JavaScript
[equalshares-compute-tool](https://github.com/equalshares/equalshares-compute-tool)
(parser + Method of Equal Shares) and was then extended for parity with
[pabutools](https://github.com/COMSOC-Community/pabutools), the academic reference
implementation. Every rule and satisfaction measure is cross-checked against pabutools
(see [Tests](#tests)).

Highlights:

- **Rules**: Method of Equal Shares (`mes`), Phragmén's sequential rule (`phragmen`),
  greedy utilitarian welfare (`greedy`), maximin support (`maximin`).
- **Ballots**: approval, cardinal (`scoring` / `cumulative`), and ordinal (via Borda).
- **Satisfaction measures**: `cost` (the equalshares.net default), `cardinality`, `effort`.
- **Exact or fast**: exact rational arithmetic (`fractions`) or floating point (`floats`).
- **No runtime dependencies**; the maximin rule is solved with a pure-Ruby max-flow
  instead of an LP solver.

## Installation

Install from git (or build the gem locally):

```bash
gem install specific_install
gem specific_install https://github.com/takahashim/equalshares.git
```

or add to a Gemfile:

```ruby
gem "equalshares", git: "https://github.com/takahashim/equalshares.git"
```

## Command line

```bash
# Compute winners with exact arithmetic
equalshares path/to/instance.pb --completion add1 --accuracy fractions

# Choose the rule and satisfaction measure
equalshares instance.pb --rule phragmen
equalshares instance.pb --rule greedy --satisfaction cardinality
equalshares instance.pb --rule maximin

# Output formats and tie-breaking
equalshares instance.pb --format csv
equalshares instance.pb --format json
equalshares instance.pb --tie-breaking maxVotes,minCost --comparison satisfaction --progress
```

Options: `--rule` (`mes`/`phragmen`/`greedy`/`maximin`), `--completion`
(`none`/`utilitarian`/`add1`/`add1u`/…), `--accuracy` (`floats`/`fractions`),
`--satisfaction` (`cost`/`cardinality`/`effort`), `--tie-breaking`
(comma-separated `maxVotes,minCost,maxCost`), `--add1-options` (`exhaustive,integral`),
`--comparison` (`none`/`satisfaction`/`exclusionRatio`), `--increment N`, `--format`
(`human`/`csv`/`json`), `--progress`.

## Library

```ruby
require "equalshares"

instance = Equalshares::Pabulib.parse_file("instance.pb")
params   = Equalshares::Params.new(completion: "add1u", accuracy: "fractions")

result = Equalshares::Compute.equal_shares(instance, params)
result[:winners]        # => ["24", "41", ...] winning project IDs
result[:notes][:stats]  # => total_cost, avg_approved_projects, utility_distribution, ...

# Other rules
Equalshares::Phragmen.sequential(instance, params)
Equalshares::Greedy.utilitarian_welfare(instance, Equalshares::Params.new(satisfaction: "cardinality"))
Equalshares::Maximin.support(instance)

# Serialise back to .pb
Equalshares::Pabulib.write_file(instance, "out.pb")
```

### Satisfaction measures

By default MES uses **cost** satisfaction (the equalshares.net rule). `cardinality`
(each funded approved project counts as 1) and `effort` (cost divided by approver count)
are also supported and match pabutools' `Cost_Sat`, `Cardinality_Sat` and `Effort_Sat`.

### Ballot types

`scoring` / `cumulative` instances carry per-voter scores (a `points` column); `ordinal`
instances carry rankings, converted to per-voter **Borda** scores (ballot length − rank
− 1). In all cases `instance.cardinal?` is true and the utilities feed the general MES
(`Equalshares::MesGeneral`), verified against pabutools' `Additive_Cardinal_Sat` and
`Additive_Borda_Sat`.

### Tie-breaking

`params.tie_breaking` is a priority list of: the criteria `"maxVotes"`, `"minCost"`,
`"maxCost"`; a total order `{ lexico: [ids...] }` that ranks tied projects by their
position in the list (matches pabutools' lexicographic tie-breaking — the recommended
form); or a bare `Array`, which reproduces the equalshares.net tool's explicit-list
behaviour but does **not** respect the list ordering.

## Tests

```bash
bundle install
bundle exec rake test
```

The suite cross-checks the implementation against the original JavaScript tool and
against pabutools. The pabutools reference fixtures under `test/fixtures/` are committed,
so the tests run without pabutools installed (the pabutools cross-checks skip if their
reference JSON is absent). To regenerate a reference, install `pabutools`
(`pip install pabutools`) and run the corresponding `test/fixtures/generate_*.py` script.

## License

MIT. The Method of Equal Shares algorithm and pabulib parser are ports of the
MIT-licensed [equalshares-compute-tool](https://github.com/equalshares/equalshares-compute-tool)
by Dominik Peters. See `LICENSE.txt`.
