"""Independent reference from pabutools for ordinal-ballot MES (Borda utilities).

For each synthetic ordinal fixture, records the pure-MES winner set under additive
Borda satisfaction (u_i(c) = ballot length - rank - 1), plus pabutools' lexico tie
order. The Ruby port turns ordinal ballots into per-voter Borda scores at parse time
and reuses the general (cardinal) MES.

Requires pabutools. Regenerate with:
  python3 test/fixtures/generate_pabutools_ordinal_reference.py \
      test/fixtures/pabutools_ordinal_reference.json
"""

import glob
import json
import os
import sys

from pabutools.election import parse_pabulib, Additive_Borda_Sat
from pabutools.rules import method_of_equal_shares
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(path):
    instance, profile = parse_pabulib(path)
    order = [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]
    alloc = method_of_equal_shares(
        instance, profile, sat_class=Additive_Borda_Sat, tie_breaking=lexico_tie_breaking
    )
    return {"lexico_order": order, "winners": sorted(p.name for p in alloc)}


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_ordinal_reference.json"
    result = {}
    for path in sorted(glob.glob(os.path.join(REPO, "test/fixtures/pb_ordinal/*.pb"))):
        rel = os.path.relpath(path, REPO)
        result[rel] = run(path)
        print(f"{rel}: {len(result[rel]['winners'])} winners")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
