#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v dart >/dev/null 2>&1; then
  if [[ -x .fvm/flutter_sdk/bin/dart ]]; then
    export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
  fi
fi

if ! command -v dart >/dev/null 2>&1; then
  echo "error: dart not found; install FVM and run fvm use, or put dart on PATH" >&2
  exit 1
fi

if ! command -v buf >/dev/null 2>&1; then
  echo "error: buf not found" >&2
  exit 1
fi

dart pub global activate protoc_plugin 25.0.0
export PATH="${PUB_CACHE:-$HOME/.pub-cache}/bin:$PATH"
buf generate
