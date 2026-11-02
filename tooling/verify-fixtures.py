"""Verify fixed local test inputs and documented Flutter tool registrations."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parent.parent
errors = []
manifest = json.loads((root / 'test-fixtures/manifest.json').read_text(encoding='utf-8'))
for entry in manifest['files']:
    path = (root / entry['path']).resolve()
    if not path.is_relative_to(root / 'test-fixtures'):
        errors.append('Fixture escapes test directory: ' + entry['path'])
        continue
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        errors.append('Fixture mismatch: ' + entry['path'])
catalogue = (root / 'docs/FUNCTIONS.md').read_text(encoding='utf-8')
registry = json.loads((root / 'docs/tool-registry.json').read_text(encoding='utf-8'))
for app, function, expected in [('Handy Tools', '_tool', 17), ('Handy Dev', 'DevTool', 24)]:
    entries = registry[app]
    source = (root / entries[0]['source']).read_text(encoding='utf-8')
    ids = re.findall(rf"{function}\(\s*'([^']+)'", source)
    if len(entries) != expected or ids != [entry['id'] for entry in entries]:
        errors.append(app + ': documented registry differs from Dart source')
    for entry in entries:
        if f"`{entry['id']}`" not in catalogue:
            errors.append('Undocumented tool: ' + entry['id'])
report = {'passed': not errors, 'errors': errors, 'verifiedFixtures': len(manifest['files']),
          'documentedTools': sum(len(entries) for entries in registry.values())}
evidence = root / 'docs/qa/evidence'
evidence.mkdir(parents=True, exist_ok=True)
(evidence / 'fixture-verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
raise SystemExit(1 if errors else 0)
