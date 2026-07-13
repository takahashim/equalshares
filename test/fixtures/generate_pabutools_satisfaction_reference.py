"""Independent reference from pabutools for the generalised satisfaction measures.

For each subsampled fixture, records the pure-MES (no completion) winner set under
each supported satisfaction measure, plus pabutools' lexicographic tie order so the
Ruby side can resolve ties identically. Confirms the Ruby port matches pabutools for
both Cost_Sat and Cardinality_Sat.

Requires pabutools. Regenerate with:
  python3 test/fixtures/generate_pabutools_satisfaction_reference.py \
      test/fixtures/pabutools_satisfaction_reference.json
"""

import json
import os
import sys

from pabutools.election import parse_pabulib, Cost_Sat, Cardinality_Sat, Effort_Sat
from pabutools.rules import method_of_equal_shares
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Subsampled fixtures only (fast for pabutools; the full Wieliczka instance is slow
# under pabutools for the non-cost measures).
FILES = [
    "test/fixtures/pb/poland_warszawa_2021_bielany.pb",
    "test/fixtures/pb/netherlands_amsterdam_2022_west.pb",
    "test/fixtures/pb/hungary_budapest_2024.pb",
]

MEASURES = {"cost": Cost_Sat, "cardinality": Cardinality_Sat, "effort": Effort_Sat}


def run(path):
    instance, profile = parse_pabulib(path)
    rec = {"lexico_order": [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]}
    for name, sat in MEASURES.items():
        alloc = method_of_equal_shares(instance, profile, sat_class=sat, tie_breaking=lexico_tie_breaking)
        rec[name] = sorted(p.name for p in alloc)
    return rec


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_satisfaction_reference.json"
    result = {}
    for rel in FILES:
        result[rel] = run(os.path.join(REPO, rel))
        counts = {m: len(result[rel][m]) for m in MEASURES}
        print(f"{rel}: {counts}")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
