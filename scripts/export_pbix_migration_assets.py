#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path
from typing import Any

from pbixray import PBIXRay


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export Power BI migration artifacts for the book club project."
    )
    parser.add_argument("--pbix", required=True, help="Path to the source PBIX file.")
    parser.add_argument(
        "--out",
        default="artifacts",
        help="Directory to write generated artifacts into.",
    )
    return parser.parse_args()


def dataframe_records(df: Any) -> list[dict[str, Any]]:
    if df is None or getattr(df, "empty", False):
        return []
    return json.loads(df.to_json(orient="records", date_format="iso", force_ascii=False))


def read_report_layout(pbix_path: Path) -> dict[str, Any]:
    with zipfile.ZipFile(pbix_path) as archive:
        if "Report/Layout" not in archive.namelist():
            return {}
        return json.loads(archive.read("Report/Layout").decode("utf-16-le"))


def summarize_layout(layout: dict[str, Any]) -> list[dict[str, Any]]:
    pages: list[dict[str, Any]] = []
    for section in layout.get("sections", []):
        page = {
            "name": section.get("displayName"),
            "filters": section.get("filters"),
            "visuals": [],
        }
        for visual in section.get("visualContainers", []):
            config_raw = visual.get("config")
            if not config_raw:
                continue
            try:
                config = json.loads(config_raw)
            except json.JSONDecodeError:
                continue
            single_visual = config.get("singleVisual", {})
            query_fields: list[str] = []
            for select in single_visual.get("prototypeQuery", {}).get("Select", []):
                name = select.get("Name")
                if name:
                    query_fields.append(name)
            page["visuals"].append(
                {
                    "type": single_visual.get("visualType"),
                    "fields": query_fields,
                }
            )
        pages.append(page)
    return pages


def export_extractable_tables(model: PBIXRay, out_dir: Path) -> list[dict[str, Any]]:
    csv_dir = out_dir / "csv"
    csv_dir.mkdir(parents=True, exist_ok=True)
    results: list[dict[str, Any]] = []

    for table_name in list(model.tables):
        table_result = {"table": table_name, "status": "skipped"}
        try:
            dataframe = model.get_table(table_name)
            csv_path = csv_dir / f"{table_name}.csv"
            dataframe.to_csv(csv_path, index=False)
            table_result.update(
                {
                    "status": "exported",
                    "rows": len(dataframe),
                    "columns": list(dataframe.columns),
                    "path": str(csv_path),
                }
            )
        except Exception as exc:  # pragma: no cover - best-effort export
            table_result.update(
                {
                    "status": "error",
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
        results.append(table_result)

    return results


def group_schema(records: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        grouped.setdefault(record["TableName"], []).append(record)
    return grouped


def main() -> int:
    args = parse_args()
    pbix_path = Path(args.pbix).expanduser().resolve()
    out_dir = Path(args.out).expanduser().resolve()

    if not pbix_path.exists():
        print(f"PBIX file not found: {pbix_path}", file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)

    model = PBIXRay(str(pbix_path))
    layout = read_report_layout(pbix_path)
    schema_records = dataframe_records(model.schema)
    export_status = export_extractable_tables(model, out_dir)

    report = {
        "pbix_path": str(pbix_path),
        "tables": list(model.tables),
        "schema": group_schema(schema_records),
        "relationships": dataframe_records(model.relationships),
        "measures": dataframe_records(model.dax_measures),
        "dax_tables": dataframe_records(model.dax_tables),
        "power_queries": dataframe_records(model.power_query),
        "statistics": dataframe_records(model.statistics),
        "report_pages": summarize_layout(layout),
        "table_exports": export_status,
    }

    report_path = out_dir / "current_state.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    schema_src = Path(__file__).resolve().parent.parent / "sql" / "bookclub.sqlite.sql"
    schema_dst = out_dir / "bookclub.sqlite.sql"
    shutil.copyfile(schema_src, schema_dst)

    manifest = {
        "report": str(report_path),
        "schema_sql": str(schema_dst),
        "csv_exports": [row for row in export_status if row["status"] == "exported"],
        "failed_exports": [row for row in export_status if row["status"] == "error"],
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Wrote migration artifacts to {out_dir}")
    print(f"- current model report: {report_path}")
    print(f"- target schema: {schema_dst}")
    print(f"- manifest: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
