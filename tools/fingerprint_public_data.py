#!/usr/bin/env python3
"""Deterministic OSG business-data fingerprint for migration preservation proofs.

Hashes every ordinary table in public (except the technical migration ledger) and
a small allow-list of stable semantic views. Rows are canonicalized by PostgreSQL
as jsonb text and sorted before hashing, so physical row order does not matter.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

import psycopg
from psycopg import sql

EXCLUDED_TABLES = {"osg_schema_migration"}
STABLE_VIEWS = {
    "osg_allocation_fact",
    "osg_settlement_balance",
    "osg_folio_balance",
    "osg_guest_profile_canonical_map",
    "osg_completed_stay_guest_fact",
}


def connect_kwargs(dbname: str | None = None) -> dict[str, object]:
    kwargs: dict[str, object] = {}
    mapping = {
        "PGHOST": "host",
        "PGPORT": "port",
        "PGUSER": "user",
        "PGPASSWORD": "password",
        "PGDATABASE": "dbname",
    }
    for env_name, kw_name in mapping.items():
        value = os.getenv(env_name)
        if value:
            kwargs[kw_name] = int(value) if env_name == "PGPORT" else value
    if dbname:
        kwargs["dbname"] = dbname
    return kwargs


def relation_names(conn: psycopg.Connection, relkind: str) -> list[str]:
    rows = conn.execute(
        """
        select c.relname
        from pg_class c
        join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public' and c.relkind=%s
        order by c.relname
        """,
        (relkind,),
    ).fetchall()
    return [row[0] for row in rows]


def hash_relation(conn: psycopg.Connection, name: str) -> dict[str, object]:
    query = sql.SQL(
        "select to_jsonb(t)::text from {}.{} t order by to_jsonb(t)::text"
    ).format(sql.Identifier("public"), sql.Identifier(name))
    digest = hashlib.sha256()
    count = 0
    with conn.cursor() as cur:
        cur.execute(query)
        for (row_text,) in cur:
            digest.update(row_text.encode("utf-8"))
            digest.update(b"\n")
            count += 1
    return {"rows": count, "sha256": digest.hexdigest()}


def build_fingerprint(dbname: str | None) -> dict[str, object]:
    objects: dict[str, dict[str, object]] = {}
    with psycopg.connect(**connect_kwargs(dbname)) as conn:
        for name in relation_names(conn, "r"):
            if name in EXCLUDED_TABLES:
                continue
            objects[f"table:{name}"] = hash_relation(conn, name)

        available_views = set(relation_names(conn, "v"))
        for name in sorted(STABLE_VIEWS & available_views):
            objects[f"view:{name}"] = hash_relation(conn, name)

    canonical = json.dumps(objects, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {
        "format_version": 1,
        "object_count": len(objects),
        "objects": objects,
        "global_sha256": hashlib.sha256(canonical).hexdigest(),
    }


def compare(left: Path, right: Path) -> int:
    a = json.loads(left.read_text(encoding="utf-8"))
    b = json.loads(right.read_text(encoding="utf-8"))
    if a != b:
        a_objs = a.get("objects", {})
        b_objs = b.get("objects", {})
        names = sorted(set(a_objs) | set(b_objs))
        differences = [name for name in names if a_objs.get(name) != b_objs.get(name)]
        print("OSG_DATA_PRESERVATION_MISMATCH", file=sys.stderr)
        for name in differences[:50]:
            print(
                f"  {name}: source={a_objs.get(name)!r} target={b_objs.get(name)!r}",
                file=sys.stderr,
            )
        if len(differences) > 50:
            print(f"  ... {len(differences)-50} additional differences", file=sys.stderr)
        return 1
    print(
        "OSG_DATA_PRESERVATION PASS "
        f"objects={a['object_count']} global_sha256={a['global_sha256']}"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dbname")
    parser.add_argument("--output")
    parser.add_argument("--compare", nargs=2, metavar=("SOURCE", "TARGET"))
    args = parser.parse_args()

    if args.compare:
        return compare(Path(args.compare[0]), Path(args.compare[1]))
    if not args.output:
        parser.error("--output is required unless --compare is used")

    result = build_fingerprint(args.dbname)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "OSG_DATA_FINGERPRINT "
        f"objects={result['object_count']} global_sha256={result['global_sha256']} output={output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
