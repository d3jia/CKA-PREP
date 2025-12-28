#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

print_result() {
  local qnum="$1"
  local status="$2"
  local output="$3"

  printf "Q%s %s\n" "$qnum" "$status"
  if [[ -n "$output" ]]; then
    printf "%s\n" "$output" | sed 's/^/  /'
  fi
  printf "\n"
}

found_any=false

for dir in "$root_dir"/Question-*; do
  [[ -d "$dir" ]] || continue
  found_any=true

  qnum="${dir##*/}"
  qnum="${qnum#Question-}"
  validate_script="$dir/validate.sh"

  if [[ ! -f "$validate_script" ]]; then
    print_result "$qnum" "⚠️" "validate.sh not found"
    continue
  fi

  if [[ ! -x "$validate_script" ]]; then
    chmod +x "$validate_script" 2>/dev/null || true
  fi

  set +e
  output=$(bash "$validate_script" 2>&1)
  exit_code=$?
  set -e

  if [[ $exit_code -eq 0 ]]; then
    print_result "$qnum" "✅" "$output"
  else
    print_result "$qnum" "❌" "$output"
  fi
 done

if [[ "$found_any" == false ]]; then
  echo "No Question-* directories found." >&2
  exit 1
fi
