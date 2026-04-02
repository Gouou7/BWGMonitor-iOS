#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/.version"
PROJECT_FILE="$ROOT_DIR/project.yml"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Missing version file: $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

if [[ -z "$VERSION" ]]; then
  echo "Version file is empty: $VERSION_FILE" >&2
  exit 1
fi

MARKETING_VERSION="${VERSION%%-*}"

if [[ -z "$MARKETING_VERSION" ]]; then
  echo "Failed to derive MARKETING_VERSION from $VERSION" >&2
  exit 1
fi

python3 - "$PROJECT_FILE" "$MARKETING_VERSION" <<'PY'
from pathlib import Path
import re
import sys

project_path = Path(sys.argv[1])
version = sys.argv[2]
text = project_path.read_text()
updated, count = re.subn(
    r"(^\s*MARKETING_VERSION:\s*).*$",
    rf"\g<1>{version}",
    text,
    count=1,
    flags=re.MULTILINE,
)

if count != 1:
    raise SystemExit("Failed to locate MARKETING_VERSION in project.yml")

project_path.write_text(updated)
PY

echo "Synchronized MARKETING_VERSION to $MARKETING_VERSION (source: $VERSION)"
