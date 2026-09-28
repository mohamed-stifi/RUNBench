#!/usr/bin/env python3
"""validate-verdict.py — validate evaluator verdict JSON (Issue #08).

Usage: validate-verdict.py VERDICT_JSON
Exit 0 VERDICT-VALID, 1 with clear field errors.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate-verdict.py VERDICT_JSON", file=sys.stderr)
        return 2
    try:
        import jsonschema
    except ImportError:
        print("VERDICT-ERROR: jsonschema not installed (need .venv per README)", file=sys.stderr)
        return 2
    schema = json.loads((ROOT / "evaluator" / "verdict.schema.json").read_text())
    try:
        verdict = json.loads(Path(sys.argv[1]).read_text())
    except (OSError, json.JSONDecodeError) as e:
        print(f"VERDICT-INVALID: cannot parse: {e}", file=sys.stderr)
        return 1
    errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(verdict),
                    key=lambda e: list(e.path))
    if errors:
        for e in errors:
            where = ".".join(str(p) for p in e.absolute_path) or "(root)"
            print(f"VERDICT-INVALID: field '{where}': {e.message}")
        return 1
    print("VERDICT-VALID")
    return 0


if __name__ == "__main__":
    sys.exit(main())
