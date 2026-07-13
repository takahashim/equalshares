"""Generate an independent reference from pabutools (the academic reference
implementation of the Method of Equal Shares) for cross-checking the Ruby port.

The equalshares.net tool (and hence this Ruby port) implements MES with *cost*
satisfaction and exact arithmetic. This was confirmed empirically: the port's
`completion=none, accuracy=fractions` output matches pabutools' `Cost_Sat` exactly,
and does NOT match `Cardinality_Sat`.

For each instance we record, for the pure rule (no completion / budget increment):
  - the full lexicographic tie-breaking order of project ids, so the Ruby side can
    resolve ties identically (fed to Params as an explicit candidate-order list), and
  - the resulting set of funded project ids and their total cost.

Requires pabutools (pip install pabutools). Regenerate with:
  python3 test/fixtures/generate_pabutools_reference.py test/fixtures/pabutools_reference.json
"""

import json
import os
import sys

from pabutools.election import parse_pabulib, Cost_Sat
from pabutools.rules import method_of_equal_shares
from pabutools.tiebreaking import lexico_tie_breaking

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

FILES = [
    "test/fixtures/poland_wieliczka_2023_green-budget.pb",
    "test/fixtures/pb/poland_warszawa_2021_bielany.pb",
    "test/fixtures/pb/netherlands_amsterdam_2022_west.pb",
    "test/fixtures/pb/hungary_budapest_2024.pb",
]


def run(path):
    instance, profile = parse_pabulib(path)
    order = [p.name for p in lexico_tie_breaking.order(instance, profile, list(instance))]
    alloc = method_of_equal_shares(
        instance, profile, sat_class=Cost_Sat, tie_breaking=lexico_tie_breaking
    )
    winners = sorted(p.name for p in alloc)
    total_cost = int(sum(p.cost for p in alloc))
    return {
        "lexico_order": order,
        "winners": winners,
        "total_cost": total_cost,
        "budget_limit": str(instance.budget_limit),
    }


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "test/fixtures/pabutools_reference.json"
    result = {}
    for rel in FILES:
        result[rel] = run(os.path.join(REPO, rel))
        print(f"{rel}: {len(result[rel]['winners'])} winners, cost={result[rel]['total_cost']}")
    with open(os.path.join(REPO, out_path), "w") as f:
        json.dump(result, f, indent=2)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
