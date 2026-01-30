#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bump-version.sh <marketing_version> [--build <build_number>] [--file <path>]

Examples:
  bump-version.sh 0.0.3
  bump-version.sh 0.0.3 --build 12
  bump-version.sh 0.0.3 --file Config/Shared.xcconfig
USAGE
}

file="Config/Shared.xcconfig"
marketing_version=""
build=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --file)
      file="$2"
      shift 2
      ;;
    --build)
      build="$2"
      shift 2
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -z "$marketing_version" ]]; then
        marketing_version="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$marketing_version" ]]; then
  usage
  exit 1
fi

python3 - "$file" "$marketing_version" "$build" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
marketing = sys.argv[2]
build_arg = sys.argv[3]

text = path.read_text()

m = re.search(r"^(MARKETING_VERSION\s*=\s*).*$", text, flags=re.M)
if not m:
  print("MARKETING_VERSION not found", file=sys.stderr)
  sys.exit(1)

b = re.search(r"^(CURRENT_PROJECT_VERSION\s*=\s*).*$", text, flags=re.M)
if not b:
  print("CURRENT_PROJECT_VERSION not found", file=sys.stderr)
  sys.exit(1)

if build_arg:
  build = build_arg
else:
  current = b.group(0).split("=")[-1].strip()
  try:
    build = str(int(current) + 1)
  except ValueError:
    print(f"CURRENT_PROJECT_VERSION is not an int: {current}", file=sys.stderr)
    sys.exit(1)

text = re.sub(r"^(MARKETING_VERSION\s*=\s*).*$", rf"\1{marketing}", text, flags=re.M)
text = re.sub(r"^(CURRENT_PROJECT_VERSION\s*=\s*).*$", rf"\1{build}", text, flags=re.M)

path.write_text(text)
print(f"Set MARKETING_VERSION={marketing}")
print(f"Set CURRENT_PROJECT_VERSION={build}")
PY
