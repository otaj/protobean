#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

dart_version=$(awk '/^version:/ { print $2; exit }' pubspec.yaml)
python_version=$(awk -F '"' '/^version = "/ { print $2; exit }' pyproject.toml)

if [[ -z "$dart_version" ]]; then
  echo "error: could not read version from pubspec.yaml" >&2
  exit 1
fi
if [[ -z "$python_version" ]]; then
  echo "error: could not read version from pyproject.toml" >&2
  exit 1
fi

if [[ "$dart_version" != "$python_version" ]]; then
  echo "error: dart version '$dart_version' does not match python version '$python_version'" >&2
  exit 1
fi

if [[ -n "${TAG_VERSION:-}" && "$dart_version" != "$TAG_VERSION" ]]; then
  echo "error: package version '$dart_version' does not match tag '$TAG_VERSION'" >&2
  exit 1
fi

echo "$dart_version"
