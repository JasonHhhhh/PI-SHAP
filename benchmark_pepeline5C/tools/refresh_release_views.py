#!/usr/bin/env python3
import csv
import os
import re
import shutil


def norm_stem(stem: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9]+", "_", stem).strip("_").lower()
    slug = re.sub(r"_+", "_", slug)
    return slug or "artifact"


def rebuild_maps(project_root: str) -> None:
    figure_sources = [
        ("modules/performance3/top1_optimality_package/figures", "perf3_top1"),
        ("modules/performance3/source_runs/single_cost_s020_abs_reviewer/plots", "single_cost_metric"),
        ("modules/performance3/source_runs/single_cost_s020_fontfix_reviewer/plots", "single_cost_action"),
        ("modules/performance3/source_runs/multi_objective_s020_reviewer/plots", "multi_objective"),
        ("modules/performance3/rule_learner_compare/plots", "rule_compare"),
        ("modules/shap_vs_nn/plots", "shap_vs_nn"),
        ("modules/doe", "doe"),
        ("modules/sim", "sim"),
    ]

    table_sources = [
        ("modules/performance3/top1_optimality_package/tables", "perf3_top1_tables", {".csv", ".json", ".mat"}),
        ("modules/performance3/source_runs/single_cost_s020_abs_reviewer/tables", "single_cost_source_tables", {".csv", ".json", ".mat"}),
        ("modules/performance3/source_runs/single_cost_s020_fontfix_reviewer/tables", "single_cost_source_tables", {".csv", ".json", ".mat"}),
        ("modules/performance3/source_runs/multi_objective_s020_reviewer/tables", "multi_objective_source_tables", {".csv", ".json", ".mat"}),
        ("modules/performance3/rule_learner_compare/tables", "rule_compare_tables", {".csv", ".json", ".mat"}),
        ("modules/shap_vs_nn/reports", "nn_reports_tables", {".csv"}),
        ("modules/doe/try1", "doe_tables", {".csv", ".mat"}),
        ("modules/sim/grid_independence_refined", "sim_convergence_tables", {".csv", ".mat"}),
        ("modules/sim/grid_residual_field_study", "sim_convergence_tables", {".csv", ".mat"}),
    ]

    figure_exts = {".png", ".svg", ".pdf"}

    out_fig = os.path.join(project_root, "release", "figures")
    out_tab = os.path.join(project_root, "release", "tables")
    os.makedirs(out_fig, exist_ok=True)
    os.makedirs(out_tab, exist_ok=True)

    # Refresh figures
    if os.path.isdir(out_fig):
        shutil.rmtree(out_fig)
    os.makedirs(out_fig, exist_ok=True)

    fig_rows = []
    seen = set()
    for src_rel, group in figure_sources:
        src = os.path.join(project_root, src_rel)
        if not os.path.isdir(src):
            continue
        dst_group = os.path.join(out_fig, group)
        os.makedirs(dst_group, exist_ok=True)
        for dp, _, files in os.walk(src):
            for fn in files:
                ext = os.path.splitext(fn)[1].lower()
                if ext not in figure_exts:
                    continue
                sp = os.path.join(dp, fn)
                base = f"{group}__{norm_stem(os.path.splitext(fn)[0])}"
                new = base + ext
                k = 2
                while (group, new) in seen or os.path.exists(os.path.join(dst_group, new)):
                    new = f"{base}__{k}{ext}"
                    k += 1
                seen.add((group, new))
                dp_new = os.path.join(dst_group, new)
                shutil.copy2(sp, dp_new)
                fig_rows.append({
                    "group": group,
                    "source_path": os.path.relpath(sp, project_root),
                    "renamed_path": os.path.relpath(dp_new, project_root),
                    "source_bytes": os.path.getsize(sp),
                })

    fig_map = os.path.join(project_root, "docs", "FIGURE_RENAME_MAP.csv")
    os.makedirs(os.path.dirname(fig_map), exist_ok=True)
    with open(fig_map, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["group", "source_path", "renamed_path", "source_bytes"])
        w.writeheader()
        w.writerows(fig_rows)

    # Refresh tables
    if os.path.isdir(out_tab):
        shutil.rmtree(out_tab)
    os.makedirs(out_tab, exist_ok=True)

    tab_rows = []
    seen = set()
    for src_rel, group, exts in table_sources:
        src = os.path.join(project_root, src_rel)
        if not os.path.isdir(src):
            continue
        dst_group = os.path.join(out_tab, group)
        os.makedirs(dst_group, exist_ok=True)
        for dp, _, files in os.walk(src):
            for fn in files:
                ext = os.path.splitext(fn)[1].lower()
                if ext not in exts:
                    continue
                sp = os.path.join(dp, fn)
                base = f"{group}__{norm_stem(os.path.splitext(fn)[0])}"
                new = base + ext
                k = 2
                while (group, new) in seen or os.path.exists(os.path.join(dst_group, new)):
                    new = f"{base}__{k}{ext}"
                    k += 1
                seen.add((group, new))
                dp_new = os.path.join(dst_group, new)
                shutil.copy2(sp, dp_new)
                tab_rows.append({
                    "group": group,
                    "source_path": os.path.relpath(sp, project_root),
                    "renamed_path": os.path.relpath(dp_new, project_root),
                    "source_bytes": os.path.getsize(sp),
                })

    tab_map = os.path.join(project_root, "docs", "TABLE_RENAME_MAP.csv")
    with open(tab_map, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["group", "source_path", "renamed_path", "source_bytes"])
        w.writeheader()
        w.writerows(tab_rows)

    print(f"done: {len(fig_rows)} figures, {len(tab_rows)} table/meta artifacts")


if __name__ == "__main__":
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rebuild_maps(ROOT)
