#!/usr/bin/env python3
"""OSG production migration runner.

Applies checksum-pinned SQL migrations in lexicographic order using one PostgreSQL
session, a session advisory lock and one transaction per migration. The migration
DDL and its ledger insert commit atomically.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import sys

import psycopg

LOCK_KEY = 1329744455
LEDGER_TABLE = "osg_schema_migration"
MANIFEST_RE = re.compile(r"^([0-9a-f]{64})  ([A-Za-z0-9_.-]+\.sql)$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_manifest(migration_dir: Path) -> list[tuple[str, str]]:
    manifest = migration_dir / "CHECKSUMS.sha256"
    if not manifest.is_file():
        raise RuntimeError(f"OSG_MIGRATION_MANIFEST_MISSING path={manifest}")

    entries: list[tuple[str, str]] = []
    seen: set[str] = set()
    for line_no, raw in enumerate(manifest.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = MANIFEST_RE.fullmatch(line)
        if not match:
            raise RuntimeError(
                f"OSG_MIGRATION_MANIFEST_INVALID line={line_no} value={raw!r}"
            )
        checksum, name = match.groups()
        if name in seen:
            raise RuntimeError(f"OSG_MIGRATION_MANIFEST_DUPLICATE name={name}")
        seen.add(name)
        entries.append((name, checksum))

    if not entries:
        raise RuntimeError("OSG_MIGRATION_MANIFEST_EMPTY")

    manifest_names = [name for name, _ in entries]
    if manifest_names != sorted(manifest_names):
        raise RuntimeError("OSG_MIGRATION_MANIFEST_NOT_SORTED")

    actual_names = sorted(path.name for path in migration_dir.glob("*.sql") if path.is_file())
    if manifest_names != actual_names:
        raise RuntimeError(
            "OSG_MIGRATION_MANIFEST_FILESET_MISMATCH "
            f"manifest={manifest_names!r} actual={actual_names!r}"
        )

    for name, expected in entries:
        path = migration_dir / name
        actual = sha256_file(path)
        if actual != expected:
            raise RuntimeError(
                "OSG_MIGRATION_CHECKSUM_MISMATCH_FILE "
                f"name={name} expected={expected} actual={actual}"
            )
        text = path.read_text(encoding="utf-8")
        meta = [line for line in text.splitlines() if line.startswith("\\")]
        if meta:
            raise RuntimeError(
                f"OSG_MIGRATION_PSQL_META_NOT_ALLOWED name={name} lines={meta!r}"
            )

    return entries


def connect_kwargs() -> dict[str, object]:
    kwargs: dict[str, object] = {}
    env_to_kw = {
        "PGHOST": "host",
        "PGPORT": "port",
        "PGUSER": "user",
        "PGPASSWORD": "password",
        "PGDATABASE": "dbname",
    }
    for env_name, kw_name in env_to_kw.items():
        value = os.getenv(env_name)
        if value:
            kwargs[kw_name] = int(value) if env_name == "PGPORT" else value
    return kwargs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--migration-dir", default="database/migrations")
    args = parser.parse_args()

    migration_dir = Path(args.migration_dir)
    entries = load_manifest(migration_dir)
    print(f"OSG_MIGRATION manifest_count={len(entries)} dir={migration_dir}")

    conn = psycopg.connect(**connect_kwargs(), autocommit=True)
    try:
        conn.execute("select pg_advisory_lock(%s)", (LOCK_KEY,))
        print(f"OSG_MIGRATION advisory_lock=ACQUIRED key={LOCK_KEY}")

        conn.execute(
            f"""
            create table if not exists {LEDGER_TABLE} (
              migration_name text primary key,
              checksum_sha256 text not null check (checksum_sha256 ~ '^[0-9a-f]{{64}}$'),
              applied_at timestamptz not null default now()
            )
            """
        )

        rows = conn.execute(
            f"select migration_name, checksum_sha256 from {LEDGER_TABLE}"
        ).fetchall()
        applied = {name: checksum for name, checksum in rows}

        applied_now = 0
        skipped = 0
        for name, checksum in entries:
            previous = applied.get(name)
            if previous is not None:
                if previous != checksum:
                    raise RuntimeError(
                        "OSG_MIGRATION_LEDGER_CHECKSUM_MISMATCH "
                        f"name={name} recorded={previous} expected={checksum}"
                    )
                print(f"OSG_MIGRATION SKIP name={name} checksum={checksum}")
                skipped += 1
                continue

            sql = (migration_dir / name).read_text(encoding="utf-8")
            try:
                with conn.transaction():
                    conn.execute(sql, prepare=False)
                    conn.execute(
                        f"insert into {LEDGER_TABLE} (migration_name, checksum_sha256) values (%s,%s)",
                        (name, checksum),
                    )
            except Exception:
                print(f"OSG_MIGRATION APPLY_FAILED name={name}", file=sys.stderr)
                raise

            print(f"OSG_MIGRATION APPLIED name={name} checksum={checksum}")
            applied_now += 1

        print(
            "OSG_MIGRATION PASS "
            f"applied_now={applied_now} skipped={skipped} total={len(entries)}"
        )
        return 0
    finally:
        try:
            conn.execute("select pg_advisory_unlock(%s)", (LOCK_KEY,))
        finally:
            conn.close()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"OSG_MIGRATION_FAILURE {exc}", file=sys.stderr)
        sys.exit(1)
