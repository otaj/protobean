#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${PR_TITLE:-}" || -z "${PR_NUMBER:-}" || -z "${BASE_SHA:-}" || -z "${HEAD_SHA:-}" ]]; then
  echo "usage: PR_TITLE=... PR_NUMBER=... BASE_SHA=... HEAD_SHA=... $0" >&2
  exit 2
fi

changelog=CHANGELOG.md
expected="- ${PR_TITLE} (#${PR_NUMBER})"

if [[ ! -f "$changelog" ]]; then
  echo "error: $changelog is missing" >&2
  exit 1
fi

if ! awk '
  /^## \[Unreleased\]/ { p=1; next }
  /^## / { p=0 }
  p
' "$changelog" | grep -Fqx -- "$expected"; then
  echo "error: $changelog ## [Unreleased] must contain this exact line:" >&2
  echo "  $expected" >&2
  exit 1
fi

found=0
while IFS= read -r sha; do
  mapfile -t files < <(git diff-tree --no-commit-id --name-only -r "$sha")
  if [[ ${#files[@]} -eq 0 ]]; then
    continue
  fi
  if [[ ${#files[@]} -eq 1 && ${files[0]} == "$changelog" ]] &&
    git diff-tree -U0 --no-commit-id -p "$sha" -- "$changelog" | grep -Fqx -- "+${expected}"; then
    found=1
    break
  fi
done < <(git rev-list --reverse "${BASE_SHA}..${HEAD_SHA}")

if [[ "$found" -ne 1 ]]; then
  echo "error: add the changelog line in its own commit that only changes $changelog:" >&2
  echo "  $expected" >&2
  exit 1
fi
