"""Independent reference from pabutools for the additional voting rules.

For each subsampled fixture, records the winner set of each ported rule, plus
pabutools' lexicographic tie order so the Ruby side can resolve ties identically.

Requires pabutools. Regenerate with:
  python3 test/fixtures/generate_pabutools_rules_reference.py \
      test/fixtures/pabutools_rules_reference.json
"""

import json
import os
import sys

from pabutools.election import parse_pabulib, Cost_Sat, Cardinality_Sat
from pabutools.rules import sequential_phragmen, greedy_utilitarian_welfare
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FILES = [
    "test/fixtures/pb/poland_warszawa_2021_bielany.pb",
    "test/fixtures/pb/netherlands_amsterdam_2022_west.pb",
    "test/fixtures/pb/hungary_budapest_2024.pb",
]


def rules(instance, profile):
    result = {
        "phragmen": sorted(
            p.name
            for p in sequential_phragmen(instance, profile, tie_breaking=lexico_tie_breaking)
        ),
    }
    for name, sat in {"cost": Cost_Sat, "cardinality": Cardinality_Sat}.items():
        alloc = greedy_utilitarian_welfare(instance, profile, sat_class=sat, tie_breaking=lexico_tie_breaking)
        result[f"greedy_{name}"] = sorted(p.name for p in alloc)
    return result


def run(path):
    instance, profile = parse_pabulib(path)
    rec = {"lexico_order": [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]}
    rec.update(rules(instance, profile))
    return rec


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_rules_reference.json"
    result = {}
    for rel in FILES:
        result[rel] = run(os.path.join(REPO, rel))
        counts = {k: len(v) for k, v in result[rel].items() if k != "lexico_order"}
        print(f"{rel}: {counts}")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
