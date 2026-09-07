#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v buf >/dev/null 2>&1; then
  echo "error: buf not found" >&2
  exit 1
fi

init_file=src/protobean/__init__.py
if [[ ! -f "$init_file" ]]; then
  echo "error: $init_file is missing" >&2
  exit 1
fi

# Wipe only generated output so handwritten src/protobean files stay put.
rm -rf src/protobean/beancount
buf generate --template buf.gen.python.yaml
touch src/protobean/beancount/__init__.py

# Sibling modules are generated as `from beancount import ...`; they live in this
# package, so relative imports are enough (and avoid a top-level `beancount`).
find src/protobean/beancount -type f \( -name '*_pb2.py' -o -name '*_pb2.pyi' \) \
  -exec sed -i 's/^from beancount import /from . import /' {} +
