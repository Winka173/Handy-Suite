"""Prepare Flutter public store identifiers; never accepts private signing keys."""
import json
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: python tooling/prepare-store-config.py config/monetization.local.json")
source = Path(sys.argv[1]).read_text(encoding="utf-8-sig")
if len(source) > 30000 or "PRIVATE KEY" in source:
    raise SystemExit("Only bounded public store configuration is allowed.")
config = json.loads(source)
apps = {"docs", "media", "tools", "dev", "keep", "recall", "save", "spend", "habit"}
if not isinstance(config, dict) or set(config) != apps:
    raise SystemExit("Configuration must contain exactly the nine app keys.")
for app, platforms in config.items():
    if not isinstance(platforms, dict) or set(platforms) - {"android", "ios", "windows", "web"}:
        raise SystemExit(f"Invalid platforms for {app}")
    for platform, values in platforms.items():
        if not isinstance(values, dict) or set(values) - {"productId", "androidPublicKey", "bannerAdUnitId", "adsEnabled"}:
            raise SystemExit(f"Invalid public fields for {app}/{platform}")
        for key in ["productId", "androidPublicKey", "bannerAdUnitId"]:
            value = values.get(key, "")
            if not isinstance(value, str) or len(value) > (2048 if key == "androidPublicKey" else 200):
                raise SystemExit(f"Invalid identifier type/size for {app}/{platform}/{key}")
        product = values.get("productId", "")
        unit = values.get("bannerAdUnitId", "")
        if product and not re.fullmatch(r"[A-Za-z0-9_.-]+", product):
            raise SystemExit(f"Invalid product ID for {app}/{platform}")
        if platform == "windows" and product and not re.fullmatch(r"[A-Z0-9]{12}", product):
            raise SystemExit(f"Microsoft add-on Store ID must be 12 characters for {app}")
        if unit and not re.fullmatch(r"ca-app-pub-\d{16}/\d{10}", unit):
            raise SystemExit(f"Invalid banner ID for {app}/{platform}")
        if "adsEnabled" in values and not isinstance(values["adsEnabled"], bool):
            raise SystemExit(f"adsEnabled must be boolean for {app}/{platform}")
output = Path(__file__).resolve().parent.parent / ".tooling/monetization-defines.json"
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps({"HANDY_MONETIZATION_CONFIG": json.dumps(config, separators=(",", ":")), "HANDY_TEST_ADS": False}, indent=2) + "\n", encoding="utf-8")
print("Wrote .tooling/monetization-defines.json; no private credentials were read or printed.")
