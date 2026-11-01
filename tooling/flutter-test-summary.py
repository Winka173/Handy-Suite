"""Summarize actual Melos output; incomplete/failed runs exit unsuccessfully."""
from pathlib import Path
import hashlib
import json
import re
import sys
from datetime import datetime, timezone, timedelta

root = Path(__file__).resolve().parent.parent
path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'docs/qa/evidence/flutter-tests.log'
data = path.read_bytes()
log = data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig')
items = [{'package': name, 'passed': int(count), 'skipped': int(skipped or 0)} for count, skipped, name in re.findall(
    r'\+(\d+)(?: ~(\d+))?: All tests passed!\s*\n([a-z_]+): SUCCESS', log)]
workspace = re.findall(r'^  - ((?:apps|packages)/handy_[a-z_]+)$',
                       (root / 'pubspec.yaml').read_text(encoding='utf-8-sig'), re.M)
expected = {re.search(r'^name:\s*(\w+)', (root / p / 'pubspec.yaml').read_text(encoding='utf-8-sig'), re.M)[1]
            for p in workspace if (root / p / 'test').is_dir()}
success = ('SUCCESS' in log[-250:] and 'FAILED' not in log and
           'Some tests failed' not in log and {item['package'] for item in items} == expected and
           len(items) == len(expected))
report = {'date': datetime.now(timezone(timedelta(hours=7))).date().isoformat(), 'scope': 'Flutter unit/widget; native integration reported separately',
          'packages': items, 'totalPassed': sum(item['passed'] for item in items),
          'totalSkipped': sum(item['skipped'] for item in items),
          'melosSuccess': success, 'logSha256': hashlib.sha256(data).hexdigest(),
          'nativeIntegrationReportedSeparately': True}
(path.parent / (path.stem + '-summary.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8-sig')
print(f"{report['totalPassed']} tests; {len(items)}/{len(expected)} packages; success={success}")
raise SystemExit(0 if success else 1)

