#!/bin/bash
set -euo pipefail

REPO_URL=${REPO_URL:-"https://github.com/JavaScript-package-manager-comparison/metacubexd.git"}
RUNS=${RUNS:-1}
WARMUP=${WARMUP:-1}
RESULTS_DIR=${RESULTS_DIR:-"/results"}

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
export COREPACK_ENABLE_AUTO_PIN=0
export COREPACK_ENABLE_STRICT=0
export NPM_CONFIG_YES=true
export CI=true
export FORCE_COLOR=0
export NODE_OPTIONS="--max-old-space-size=4096"
export YARN_ENABLE_IMMUTABLE_INSTALLS=false
export YARNSW_COREPACK_COMPAT=true

source lib/utils.sh
source lib/scenario_handler.sh

for config_file in configs/*.sh; do
  [ -f "$config_file" ] && source "$config_file"
done

echo "Cloning repo: $REPO_URL"
git clone --depth 1 "$REPO_URL" /project
cd /project

cp package.json package.json.original || true
corepack enable >/dev/null 2>&1 || true

ACTIVE_MANAGERS=(
  "npm"
  "yarn-classic"
  "yarn-berry"
  "pnpm"
  "bun"
  "yarn-zpm"
#  "deno" # not work
#  "vlt" # not work
  "cotton"
)

ACTIVE_SCENARIOS=(
  "clean"
  "lockfile_only"
  "cache_only"
  "node_modules_only"
  "node_modules_lockfile"
  "node_modules_cache"
  "lockfile_cache"
  "node_modules_lockfile_cache"
)

echo "Starting benchmark for ${#ACTIVE_MANAGERS[@]} managers × ${#ACTIVE_SCENARIOS[@]} scenarios"

for manager in "${ACTIVE_MANAGERS[@]}"; do
  for scenario in "${ACTIVE_SCENARIOS[@]}"; do
    run_benchmark "$manager" "$scenario"
  done
done

echo "=================================================================="
echo "All benchmarks completed! Results in: $RESULTS_DIR"
echo "All benchmarks : $RESULTS_DIR"
echo "=================================================================="
