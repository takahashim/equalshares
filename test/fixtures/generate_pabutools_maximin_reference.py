"""Independent reference from pabutools for the maximin support rule.

For each small synthetic approval fixture, records pabutools' maximin_support winner
set plus its lexicographic tie order, so the Ruby port (an exact max-flow / max-density
solver) can be checked against it. Small instances are used because maximin solves an
optimisation per candidate per round and is slow at scale (in both implementations).

Requires pabutools. Regenerate with:
  python3 test/fixtures/generate_pabutools_maximin_reference.py \
      test/fixtures/pabutools_maximin_reference.json
"""

import glob
import json
import os
import sys

from pabutools.election import parse_pabulib
from pabutools.rules import maximin_support
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def run(path):
    instance, profile = parse_pabulib(path)
    order = [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]
    alloc = maximin_support(instance, profile, tie_breaking=lexico_tie_breaking)
    return {"lexico_order": order, "winners": sorted(p.name for p in alloc)}


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_maximin_reference.json"
    result = {}
    for path in sorted(glob.glob(os.path.join(REPO, "test/fixtures/pb_maximin/*.pb"))):
        rel = os.path.relpath(path, REPO)
        result[rel] = run(path)
        print(f"{rel}: {len(result[rel]['winners'])} winners")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
