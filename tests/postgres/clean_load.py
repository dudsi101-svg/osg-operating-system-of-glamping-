"""Issue #8: real PostgreSQL, disposable DEV only. No simulated database passes."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'proof-results'
OUT.mkdir(exist_ok=True)
results = []


def sql(label, *, path=None, command=None):
    args = ['psql', '-X', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose']
    args += ['-f', str(ROOT / path)] if path else ['-c', command]
    process = subprocess.run(args, text=True, capture_output=True, timeout=90, cwd=ROOT)
    log = process.stdout + process.stderr
    (OUT / f'{len(results):03}_{Path(label).name}.log').write_text(log)
    results.append({'step':label,'exit_code':process.returncode})
    print(f"{'PASS' if process.returncode == 0 else 'FAIL'} {label}", flush=True)
    if process.returncode:
        print(log, flush=True)
        raise RuntimeError(label)
    return process.stdout


def main():
    if os.environ.get('OSG_PROOF_DISPOSABLE') != '1':
        raise RuntimeError('Requires explicit OSG_PROOF_DISPOSABLE=1 and a fresh DEV database')
    existing = sql('empty-database', command="SELECT count(*) FROM pg_tables WHERE schemaname='public';")
    if not re.search(r'\n\s*0\s*\n', existing):
        raise RuntimeError('Refusing a nonempty database; this runner does not drop data')
    sql('postgres-version', command='SELECT version();')
    guide = (ROOT/'database/README.md').read_text()
    load = re.findall(r'^\d+\. `((?:schema|proof|semantic|seeds)/[^`]+\.sql)`', guide, re.M)
    if len(load) != 34:
        raise RuntimeError(f'Review canonical load order change: expected 34 entries, got {len(load)}')
    for path in load:
        # Includes RLS in this isolated proof DB; scenarios load as owner, NOT an RLS pass.
        sql('database/'+path,path='database/'+path)
    for path in sorted((ROOT/'database/seeds').glob('scenario_*.sql')):
        sql(str(path.relative_to(ROOT)),path=path.relative_to(ROOT))
    sql('scenario-11',path='tests/sql/scenario_11_resource_capacity_v0.96.sql')
    # Existing p0/folio/charge files contain commented assertions: never count them as gates.
    views = subprocess.check_output(['psql','-X','-At','-c',
        "SELECT viewname FROM pg_views WHERE schemaname='public' ORDER BY viewname;"],text=True).splitlines()
    if not views:
        raise RuntimeError('No semantic views found')
    for view in views:
        quoted = '"'+view.replace('"','""')+'"'
        sql('view-'+view,command='SELECT * FROM '+quoted+' LIMIT 1;')
    print('Issue #8 baseline load passed; concurrency/API/jobs gates remain separate.',flush=True)


try:
    main()
except Exception as error:
    print(f'PROOF FAILED: {error}',file=sys.stderr)
    sys.exit_code = 1
else:
    sys.exit_code = 0
finally:
    (OUT/'summary.json').write_text(json.dumps({'source_commit':os.getenv('GITHUB_SHA'),
        'postgres_major':16,'steps':results,'status':'PASS' if getattr(sys,'exit_code',1)==0 else 'FAIL',
        'scope':'README load order, reference scenarios, semantic views; NOT Schema v1.0 FINAL'},indent=2))
sys.exit(sys.exit_code)
