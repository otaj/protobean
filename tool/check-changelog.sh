#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

changelog=CHANGELOG.md

usage() {
  echo "usage: PR_TITLE=... PR_NUMBER=... BASE_SHA=... HEAD_SHA=... $0" >&2
  echo "       $0 --unreleased-empty" >&2
  exit 2
}

pubspec_version() {
  awk '/^version:/ { print $2; exit }' "$1"
}

pyproject_version() {
  awk -F '"' '/^version = "/ { print $2; exit }' "$1"
}

unreleased_bullets() {
  awk '
    /^## \[Unreleased\]/ { p=1; next }
    /^## / { p=0 }
    p && /^- / { print }
  ' "$1"
}

section_bullets() {
  local ver=$1 file=$2
  awk -v ver="$ver" '
    BEGIN { h = "## [" ver "]" }
    $0 == h || index($0, h " - ") == 1 { p=1; next }
    /^## / { p=0 }
    p && /^- / { print }
  ' "$file"
}

has_version_heading() {
  local ver=$1 file=$2
  local escaped
  escaped=$(printf '%s' "$ver" | sed 's/\./\\./g')
  grep -Eq "^## \[${escaped}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" "$file"
}

require_changelog() {
  if [[ ! -f "$changelog" ]]; then
    echo "error: $changelog is missing" >&2
    exit 1
  fi
}

check_unreleased_empty() {
  require_changelog
  local bullets
  bullets=$(unreleased_bullets "$changelog")
  if [[ -n "$bullets" ]]; then
    echo "error: $changelog ## [Unreleased] must be empty before publishing:" >&2
    printf '%s\n' "$bullets" >&2
    exit 1
  fi
}

check_entry_mode() {
  local expected="- ${PR_TITLE} (#${PR_NUMBER})"
  if ! unreleased_bullets "$changelog" | grep -Fqx -- "$expected"; then
    echo "error: $changelog ## [Unreleased] must contain this exact line:" >&2
    echo "  $expected" >&2
    echo "hint: to cut a release, bump pubspec.yaml and pyproject.toml to the same new version and move every ## [Unreleased] entry under ## [<version>] - YYYY-MM-DD" >&2
    exit 1
  fi

  local found=0 sha
  local -a files
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
}

check_release_mode() {
  local base_changelog=$1 new_ver=$2 base_ver=$3

  if [[ "$new_ver" == "$base_ver" ]] || ! printf '%s\n' "$base_ver" "$new_ver" | sort -C -V; then
    echo "error: package version '$new_ver' must be greater than '$base_ver'" >&2
    exit 1
  fi

  local head_unreleased
  head_unreleased=$(unreleased_bullets "$changelog")
  if [[ -n "$head_unreleased" ]]; then
    echo "error: $changelog ## [Unreleased] must be empty after a version bump:" >&2
    printf '%s\n' "$head_unreleased" >&2
    exit 1
  fi

  if ! has_version_heading "$new_ver" "$changelog"; then
    echo "error: $changelog must contain a heading exactly like:" >&2
    echo "  ## [$new_ver] - YYYY-MM-DD" >&2
    exit 1
  fi

  local base_unreleased
  base_unreleased=$(unreleased_bullets "$base_changelog")
  if [[ -z "$base_unreleased" ]]; then
    echo "error: $changelog ## [Unreleased] at the base commit has no entries to release" >&2
    exit 1
  fi

  if ! diff -u --label "base ## [Unreleased]" --label "## [$new_ver]" \
    <(printf '%s\n' "$base_unreleased") \
    <(section_bullets "$new_ver" "$changelog") >&2; then
    echo "error: $changelog ## [$new_ver] must contain the former ## [Unreleased] entries" >&2
    exit 1
  fi
}

if [[ "${1:-}" == "--unreleased-empty" ]]; then
  if [[ $# -ne 1 ]]; then
    usage
  fi
  check_unreleased_empty
  exit 0
fi

if [[ $# -ne 0 ]]; then
  usage
fi

if [[ -z "${PR_TITLE:-}" || -z "${PR_NUMBER:-}" || -z "${BASE_SHA:-}" || -z "${HEAD_SHA:-}" ]]; then
  usage
fi

require_changelog

base_dir=$(mktemp -d)
trap 'rm -rf "$base_dir"' EXIT

for path in pubspec.yaml pyproject.toml "$changelog"; do
  if ! git cat-file -e "${BASE_SHA}:${path}" 2>/dev/null; then
    echo "error: $path is missing at $BASE_SHA" >&2
    exit 1
  fi
  git show "${BASE_SHA}:${path}" > "$base_dir/$(basename "$path")"
done

base_dart=$(pubspec_version "$base_dir/pubspec.yaml")
base_python=$(pyproject_version "$base_dir/pyproject.toml")
head_dart=$(pubspec_version pubspec.yaml)
head_python=$(pyproject_version pyproject.toml)

if [[ -z "$base_dart" || -z "$head_dart" ]]; then
  echo "error: could not read version from pubspec.yaml" >&2
  exit 1
fi
if [[ -z "$base_python" || -z "$head_python" ]]; then
  echo "error: could not read version from pyproject.toml" >&2
  exit 1
fi

dart_bumped=0
python_bumped=0
if [[ "$head_dart" != "$base_dart" ]]; then
  dart_bumped=1
fi
if [[ "$head_python" != "$base_python" ]]; then
  python_bumped=1
fi

if [[ "$dart_bumped" -eq 1 && "$python_bumped" -eq 1 ]]; then
  if [[ "$head_dart" != "$head_python" ]]; then
    echo "error: dart version '$head_dart' does not match python version '$head_python'" >&2
    exit 1
  fi
  check_release_mode "$base_dir/$(basename "$changelog")" "$head_dart" "$base_dart"
elif [[ "$dart_bumped" -eq 1 || "$python_bumped" -eq 1 ]]; then
  echo "error: bump version in both pubspec.yaml and pyproject.toml (dart '$base_dart' -> '$head_dart', python '$base_python' -> '$head_python')" >&2
  exit 1
else
  if [[ "$head_dart" != "$head_python" ]]; then
    echo "error: dart version '$head_dart' does not match python version '$head_python'" >&2
    exit 1
  fi
  check_entry_mode
fi
