#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v buf >/dev/null 2>&1; then
  echo "error: buf not found" >&2
  exit 1
fi

init_file=src/protobean/__init__.py
typed_file=src/protobean/py.typed
if [[ ! -f "$init_file" ]]; then
  echo "error: $init_file is missing" >&2
  exit 1
fi
init_content=$(cat "$init_file")
typed_present=0
if [[ -f "$typed_file" ]]; then
  typed_present=1
fi

buf generate --template buf.gen.python.yaml

mkdir -p src/protobean/beancount
printf '%s\n' "$init_content" > "$init_file"
if [[ "$typed_present" -eq 1 ]]; then
  : > "$typed_file"
fi
touch src/protobean/beancount/__init__.py

# Generated modules import `beancount`; nest them under the protobean package.
while IFS= read -r -d '' file; do
  sed -i \
    -e 's/^from beancount /from protobean.beancount /' \
    -e 's/^import beancount\./import protobean.beancount./' \
    "$file"
done < <(find src/protobean/beancount -type f \( -name '*_pb2.py' -o -name '*_pb2.pyi' \) -print0)
