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
export YARNSW_COREPACK_COMPAT=true

export YARN_ENABLE_SCRIPTS=0
export PNPM_IGNORE_SCRIPTS=true
export BUN_INSTALL_IGNORE_SCRIPTS=true
export NPM_CONFIG_IGNORE_SCRIPTS=true
export AUBE_IGNORE_SCRIPTS=true

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
  "deno"
  "vlt"
  "cotton"
  "aube"
)

ACTIVE_SCENARIOS=(
  "clean"
  "cache_only"
  "lockfile_only"
  "node_modules_only"
  "lockfile_cache"
  "node_modules_cache"
  "node_modules_lockfile"
  "node_modules_lockfile_cache"
)

echo "Starting benchmark for ${#ACTIVE_MANAGERS[@]} managers × ${#ACTIVE_SCENARIOS[@]} scenarios"

repo_name=$(basename "$REPO_URL" .git)
global_timestamp=$(date +"%Y%m%d_%H%M%S")
START_TIME=$(date -Iseconds)
RESULTS_JSON="$RESULTS_DIR/${repo_name}_${global_timestamp}.json"

mkdir -p "$RESULTS_DIR"

cat > "$RESULTS_JSON" <<EOF
{
  "start_time": "$START_TIME",
  "repo_url": "$REPO_URL",
  "project_key": "medium",
  "hyperfine_runs": $RUNS,
  "hyperfine_warmup": $WARMUP,
  "scenarios": {}
}
EOF

echo "Results will be saved in: $RESULTS_JSON"

for manager in "${ACTIVE_MANAGERS[@]}"; do
  for scenario in "${ACTIVE_SCENARIOS[@]}"; do
    run_benchmark "$manager" "$scenario"
  done
done

echo "=================================================================="
echo "All benchmarks completed! Results in: $RESULTS_JSON"
echo "=================================================================="
