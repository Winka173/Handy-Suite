"""Hash Flutter source/config/assets, excluding generated files and local secrets."""
from pathlib import Path
import hashlib
import os
import re
import argparse

root = Path(__file__).resolve().parent.parent
workspace = re.findall(r"^  - ((?:apps|packages)/handy_[a-z_]+)$", (root / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
parser = argparse.ArgumentParser()
parser.add_argument('--app', choices=[p.removeprefix('apps/handy_') for p in workspace if p.startswith('apps/')])
selected = parser.parse_args().app
if selected:
    workspace = [p for p in workspace if not p.startswith('apps/') or p == f'apps/handy_{selected}']
if (root / 'third_party/re2').is_dir():
    workspace.append('third_party/re2')
if (root / 'third_party/json_schema').is_dir():
    workspace.append('third_party/json_schema')
skip = {"build", ".dart_tool", ".gradle", ".idea", "Pods", ".symlinks", "ephemeral", "node_modules", "test_driver", "integration_test", "test", "tool"}
extensions = {".dart", ".yaml", ".xml", ".kts", ".plist", ".pbxproj", ".png", ".ico", ".cpp", ".h", ".rc", ".json", ".html", ".js", ".swift", ".kt", ".xcconfig", ".cmake", ".txt"}
extensions.update({'.cc', '.c', '.hpp', '.ttf', '.otf', '.podspec', '.xcprivacy'})
paths = [root / "pubspec.yaml", root / "pubspec.lock", root / "analysis_options.yaml"]
for relative in workspace:
    for directory, directories, names in os.walk(root / relative):
        directories[:] = [d for d in directories if d not in skip and not d.startswith(".")]
        for name in names:
            path = Path(directory) / name
            if path.suffix in extensions and name not in {"local.properties", "Generated.xcconfig", "generated_plugin_registrant.dart"} and not name.startswith("generated_"):
                paths.append(path)
digest = hashlib.sha256()
for path in sorted(set(paths)):
    digest.update(path.relative_to(root).as_posix().encode("utf-8") + b"\x00")
    digest.update(hashlib.sha256(path.read_bytes()).digest())
print(digest.hexdigest())
