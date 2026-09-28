#!/usr/bin/env python3
"""validate.py — harness-side validation of agent result.json (Issue #06).

Usage: validate.py RESULT_JSON
Validates against harness/result.schema.json. Prints clear field errors
(missing required fields, wrong types, abstain-rule violations). Exit 0
valid, 1 invalid.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "harness" / "result.schema.json"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate.py RESULT_JSON", file=sys.stderr)
        return 2
    try:
        import jsonschema
    except ImportError:
        print("HARNESS-ERROR: jsonschema not installed (need .venv per README)", file=sys.stderr)
        return 2
    try:
        schema = json.loads(SCHEMA.read_text())
    except OSError as e:
        print(f"HARNESS-ERROR: cannot read schema: {e}", file=sys.stderr)
        return 2
    try:
        result = json.loads(Path(sys.argv[1]).read_text())
    except (OSError, json.JSONDecodeError) as e:
        print(f"HARNESS-INVALID: cannot parse result.json: {e}", file=sys.stderr)
        return 1
    validator = jsonschema.Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(result), key=lambda e: list(e.path))
    if errors:
        for e in errors:
            where = ".".join(str(p) for p in e.absolute_path) or "(root)"
            print(f"HARNESS-INVALID: field '{where}': {e.message}")
        return 1
    print("HARNESS-VALID")
    return 0


if __name__ == "__main__":
    sys.exit(main())
