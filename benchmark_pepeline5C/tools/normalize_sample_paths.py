#!/usr/bin/env python3
import csv
import os
import shutil


def normalize_value(v: str, abs_roots: list[str]) -> str:
    if not isinstance(v, str):
        return v
    for root in abs_roots:
        if v.startswith(root):
            rel = v[len(root):]
            return "${REPO_ROOT}/" + rel
    return v


def process_csv(src_csv: str, dst_csv: str, abs_roots: list[str]) -> tuple[int, int]:
    changed = 0
    rows = 0

    with open(src_csv, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fields = reader.fieldnames
        if not fields:
            return 0, 0
        data = []
        for row in reader:
            rows += 1
            out = dict(row)
            for k, v in row.items():
                nv = normalize_value(v, abs_roots)
                if nv != v:
                    changed += 1
                out[k] = nv
            data.append(out)

    os.makedirs(os.path.dirname(dst_csv), exist_ok=True)
    with open(dst_csv, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(data)

    return rows, changed


def main() -> None:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    workspace_root = os.path.abspath(os.path.join(root, ".."))
    abs_roots = {
        workspace_root.rstrip(os.sep) + os.sep,
        os.path.realpath(workspace_root).rstrip(os.sep) + os.sep,
    }
    ordered_roots = sorted(abs_roots, key=len, reverse=True)

    src_dir = os.path.join(root, "release", "tables")
    dst_dir = os.path.join(root, "release", "tables_sanitized")

    if os.path.isdir(dst_dir):
        shutil.rmtree(dst_dir)
    os.makedirs(dst_dir, exist_ok=True)

    report_rows = []
    for dp, _, files in os.walk(src_dir):
        for fn in files:
            src = os.path.join(dp, fn)
            rel = os.path.relpath(src, src_dir)
            dst = os.path.join(dst_dir, rel)

            if fn.lower().endswith(".csv"):
                n_rows, n_changed = process_csv(src, dst, ordered_roots)
                report_rows.append((rel, n_rows, n_changed))
            else:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.copy2(src, dst)
                report_rows.append((rel, 0, 0))

    rep_csv = os.path.join(root, "docs", "PATH_SANITIZE_REPORT.csv")
    with open(rep_csv, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["relative_path", "rows", "cells_changed"])
        for r in sorted(report_rows):
            w.writerow(r)

    changed_files = sum(1 for _, _, c in report_rows if c > 0)
    print(f"sanitized tables ready: {dst_dir}")
    print(f"files with changed cells: {changed_files}")
    print(rep_csv)


if __name__ == "__main__":
    main()
