#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "$0")" && pwd)
scratch=$(mktemp -d)
pnpm=${PNPM_BIN:-pnpm}
pnpr=${PNPR_BIN:-pnpr}
port=${PNPR_PORT:-7677}
registry="http://127.0.0.1:$port/npm/"
registry_pid=

cleanup() {
  if [[ -n "$registry_pid" ]]; then
    kill "$registry_pid" 2>/dev/null || true
    wait "$registry_pid" 2>/dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export CI=true
export NPM_CONFIG_USERCONFIG="$scratch/npmrc" NPM_CONFIG_GLOBALCONFIG="$scratch/npmrc"
export XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache"
export XDG_DATA_HOME="$scratch/data" PNPM_HOME="$scratch/pnpm-home"
touch "$scratch/npmrc"
printf 'pnpm: %s\npnpr: %s\n' "$("$pnpm" --version)" "$("$pnpr" --version)"

RUST_LOG=info "$pnpr" -c "$root/pnpr.yaml" --listen "127.0.0.1:$port" \
  --storage "$scratch/registry" --cache "$scratch/registry-cache" \
  --disable-resolver --disable-artifacts --disable-pipeline >"$scratch/pnpr.log" 2>&1 &
registry_pid=$!
deadline=$((SECONDS + 10))
until grep -q 'pnpr listening' "$scratch/pnpr.log"; do
  if ! kill -0 "$registry_pid" 2>/dev/null || ((SECONDS >= deadline)); then
    cat "$scratch/pnpr.log" >&2
    exit 1
  fi
  sleep 0.1
done

cp -R "$root/fixtures" "$scratch/fixtures"
for fixture in "$scratch"/fixtures/*/*; do
  (cd "$fixture" && "$pnpm" publish --no-git-checks --ignore-scripts --registry "$registry" >/dev/null)
done
cp -R "$root/project" "$scratch/project"
cd "$scratch/project"
"$pnpm" install --lockfile-only --ignore-scripts --registry "$registry"
"$pnpm" dedupe --check --ignore-scripts --registry "$registry"
printf '\npnpm dedupe --check exited 0\n'

versions=$(sed -n 's/^  repro-child@\([^:]*\):$/\1/p' pnpm-lock.yaml | sort -u)
printf '\nExpected child versions: 1.0.0\nActual child versions:\n%s\n' "$versions"
[[ "$versions" == 1.0.0 ]]
