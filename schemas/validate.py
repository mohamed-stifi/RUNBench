#!/usr/bin/env python3
"""Validate a scenario YAML/JSON file against schemas/scenario.schema.json.

Usage: validate.py <scenario-file>
Exit 0 and prints "<id> <version>" on success; exit 1 with file+field
error messages otherwise.
"""

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = json.loads((ROOT / "schemas" / "scenario.schema.json").read_text())


def load(path: Path):
    text = path.read_text()
    if path.suffix.lower() == ".json":
        return json.loads(text)
    return yaml.safe_load(text)


def main(argv: list) -> int:
    if len(argv) != 2:
        print("usage: validate.py <scenario-file>", file=sys.stderr)
        return 2
    target = argv[1]
    if not Path(target).is_file():
        print(f"scenario validate: not found: {target}", file=sys.stderr)
        return 1
    try:
        doc = load(Path(target))
    except Exception as exc:  # noqa: BLE001 - surface any parse error plainly
        print(f"scenario validate: {target}: unparsable: {exc}", file=sys.stderr)
        return 1
    errors = sorted(
        Draft202012Validator(SCHEMA).iter_errors(doc),
        key=lambda e: list(e.absolute_path),
    )
    if errors:
        for err in errors:
            field = ".".join(str(p) for p in err.absolute_path) or "(root)"
            print(f"scenario validate: {target}: {field}: {err.message}", file=sys.stderr)
        return 1
    print(f"{doc['id']} {doc['metadata']['version']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
