#!/bin/sh
set -eu

output_dir="${1:-/output}"

if [ "$#" -gt 0 ]; then
    shift
fi

mkdir -p "$output_dir"

exec mkosi --directory=/mkosi --output-dir="$output_dir" "$@"
