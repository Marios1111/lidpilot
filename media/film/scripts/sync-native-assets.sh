#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
source_dir="${repo_root}/website/assets"
destination_dir="${script_dir}/../public/native"
files=(follow-lid.png keep-screen-on.png keep-mac-running.png panel-off.png icon-light.png)

for file in "${files[@]}"; do
  if [[ ! -f "${source_dir}/${file}" ]]; then
    printf 'Missing native film source asset: %s\n' "${source_dir}/${file}" >&2
    exit 1
  fi
done

mkdir -p "${destination_dir}"
for file in "${files[@]}"; do
  cp -- "${source_dir}/${file}" "${destination_dir}/${file}"
done
