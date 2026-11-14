#!/usr/bin/env bash
set -euo pipefail

# Fetch the official Playwright seccomp profile pinned to the same release as the
# browser image. The profile keeps Docker's default restrictions and adds the
# user-namespace syscalls required by Chromium's own sandbox.
VERSION="1.65.0"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HERE/seccomp_profile.json"
TMP="$DEST.tmp"
URL="https://raw.githubusercontent.com/microsoft/playwright/v${VERSION}/utils/docker/seccomp_profile.json"

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 1; }
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$URL" --output "$TMP"
python3 - "$TMP" <<'PYCODE'
import json, sys
from pathlib import Path
payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(payload, dict) or not payload.get("defaultAction") or not isinstance(payload.get("syscalls"), list):
    raise SystemExit("Downloaded seccomp profile is not a complete Docker profile")
names = {name for rule in payload["syscalls"] if isinstance(rule, dict) for name in rule.get("names", [])}
if not {"clone", "setns", "unshare"}.issubset(names):
    raise SystemExit("Downloaded profile does not contain the Chromium user-namespace syscalls")
PYCODE
mv "$TMP" "$DEST"
chmod 0644 "$DEST"
echo "Installed Playwright v${VERSION} seccomp profile: $DEST"
