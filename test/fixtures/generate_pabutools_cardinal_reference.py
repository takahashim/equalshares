"""Independent reference from pabutools for cardinal-ballot MES.

For each synthetic scoring/cumulative fixture, records the pure-MES winner set under
additive cardinal satisfaction (u_i(c) = the voter's score), plus pabutools' lexico
tie order so the Ruby side resolves ties identically.

Requires pabutools. Regenerate with:
  python3 test/fixtures/generate_pabutools_cardinal_reference.py \
      test/fixtures/pabutools_cardinal_reference.json
"""

import glob
import json
import os
import sys

from pabutools.election import parse_pabulib, Additive_Cardinal_Sat
from pabutools.rules import method_of_equal_shares
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(path):
    instance, profile = parse_pabulib(path)
    order = [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]
    alloc = method_of_equal_shares(
        instance, profile, sat_class=Additive_Cardinal_Sat, tie_breaking=lexico_tie_breaking
    )
    return {"lexico_order": order, "winners": sorted(p.name for p in alloc)}


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_cardinal_reference.json"
    result = {}
    for path in sorted(glob.glob(os.path.join(REPO, "test/fixtures/pb_cardinal/*.pb"))):
        rel = os.path.relpath(path, REPO)
        result[rel] = run(path)
        print(f"{rel}: {len(result[rel]['winners'])} winners")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
