#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Extract FAILED / ERROR cases from a pytest text log.

Usage:
    extract_failed_cases.py LOG [--output OUT.csv] [--xlsx]

Only lines inside a pytest "short test summary info" section are parsed, so compiler or
NCCL/RCCL output containing the words ERROR/FAILED is ignored. Works on logs that contain
many pytest sessions (e.g. tests/run_test.sh output). Also records steps that the suite
runner marked as interrupted. Always writes a file (header only when there are no failures).
"""

import argparse
import csv
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1B\[[0-?]*[ -/]*[@-~]")
SUMMARY_START = re.compile(r"=+ short test summary info =+")
SESSION_START = re.compile(r"=+ test session starts =+")
SESSION_END = re.compile(r"^=+ .*(passed|failed|error|skipped|deselected|no tests ran).* in [\d.]+s")
ENTRY = re.compile(r"^(FAILED|ERROR)\s+(.+)$")
STEP = re.compile(r"^=== DS_TEST_STEP \d+: (.+)$")
INTERRUPTED = re.compile(r"^=== DS_TEST_INTERRUPTED at step (\S+)")

FIELDS = ["type", "test", "reason", "category", "rerun", "issue"]


def parse_entry(kind, rest):
    # Parameter ids may contain " - " is rare but hyphens are common; split on the last separator.
    if " - " in rest:
        test, reason = rest.rsplit(" - ", 1)
    else:
        test, reason = rest, "No detailed message (likely collection/import failure)"
    return {"type": kind, "test": test.strip(), "reason": reason.strip()}


def extract(path):
    rows, totals = [], {"passed": 0, "failed": 0, "error": 0, "skipped": 0}
    in_summary, last_step = False, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = ANSI.sub("", raw).rstrip("\n").strip()
            m = STEP.match(line)
            if m:
                last_step = m.group(1)
                continue
            m = INTERRUPTED.match(line)
            if m:
                rows.append({"type": "INTERRUPTED", "test": last_step or f"step {m.group(1)}",
                             "reason": "suite runner died during this step (killed/OOM/hang)"})
                continue
            if SESSION_START.search(line):
                in_summary = False
                continue
            if SUMMARY_START.search(line):
                in_summary = True
                continue
            if SESSION_END.match(line):
                for n, word in re.findall(r"(\d+) (passed|failed|errors?|skipped)", line):
                    totals["error" if word.startswith("error") else word] += int(n)
                in_summary = False
                continue
            if in_summary:
                m = ENTRY.match(line)
                if m:
                    rows.append(parse_entry(m.group(1), m.group(2)))
    return rows, totals


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log_path")
    ap.add_argument("--output", help="CSV path (default: failures_<logname>.csv next to the log)")
    ap.add_argument("--xlsx", action="store_true", help="also write .xlsx (needs pandas + openpyxl)")
    args = ap.parse_args()

    log = Path(args.log_path)
    if not log.is_file():
        print(f"ERROR: log not found: {log}", file=sys.stderr)
        return 2

    rows, totals = extract(log)
    out = Path(args.output) if args.output else log.with_name(f"failures_{log.stem}.csv")
    with open(out, "w", newline="", encoding="utf-8-sig") as f:  # BOM so Excel shows Chinese correctly
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})

    if args.xlsx:
        try:
            import pandas as pd
            pd.DataFrame(rows, columns=FIELDS).to_excel(out.with_suffix(".xlsx"), index=False,
                                                        sheet_name="Test Failures")
        except ImportError as e:
            print(f"WARN: xlsx skipped ({e})", file=sys.stderr)

    by_type = {}
    for r in rows:
        by_type[r["type"]] = by_type.get(r["type"], 0) + 1
    print(f"pytest totals: {totals}")
    print(f"{len(rows)} records {by_type} -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
