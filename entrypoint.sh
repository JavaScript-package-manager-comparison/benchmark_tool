#!/bin/bash
set -e

# Default values
REPO_URL=${REPO_URL:-"https://github.com/JavaScript-package-manager-comparison/metacubexd.git"}
RUNS=${RUNS:-1}
WARMUP=${WARMUP:-1}
RESULTS_DIR=${RESULTS_DIR:-"/results"}

# Disable corepack prompts
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
export COREPACK_ENABLE_AUTO_PIN=0
export COREPACK_ENABLE_STRICT=0

# Clone repository
echo "Cloning repo: $REPO_URL"
git clone --depth 1 "$REPO_URL" /project
cd /project

# package.json backup
cp package.json package.json.original || true

corepack enable || true

# Function to run benchmark for a single manager and scenario
run_benchmark() {
  local manager="$1"
  local scenario="$2"
  declare -n config="$3"

  echo "=================================================================="
  echo "Starting benchmark for manager: $manager - scenario: $scenario"
  echo "=================================================================="

  # Clean before each scenario
  rm -rf node_modules .yarn/cache .pnp.* package-lock.json yarn.lock pnpm-lock.yaml .npm

  # Restore original package.json
  cp package.json.original package.json

  # Conditional modification of package.json
  if [ "$manager" != "pnpm" ]; then
    jq 'del(.packageManager, .pnpm)' package.json > tmp.json && mv tmp.json package.json
  else
    jq 'del(.packageManager)' package.json > tmp.json && mv tmp.json package.json
  fi

  # Override packageManager field
  if [ "$manager" != "npm" ]; then
    local pm_version="${config[version]}"
    if [ "$manager" = "pnpm" ]; then
      pm_version="pnpm@10.28.2"
    fi
    jq ".packageManager = \"$pm_version\"" package.json > tmp.json && mv tmp.json package.json
  fi

  # Activate manager
  if [ -n "${config[activate_cmd]}" ]; then
    eval "${config[activate_cmd]}"
  fi

  # Force node modules directory for Yarn Berry
  if [ "$manager" = "yarn-berry" ]; then
    yarn config set nodeLinker node-modules
  fi

  # Declare install command and prepare for scenario
  case "$scenario" in
    clean)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[install_cmd]}"
      PREPARE_CMD="rm -rf node_modules .yarn/cache .pnp.* && ${config[prepare_cmd]}"
      NOTE="${config[note]} - clean install"
      ;;
    lockfile_only)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[frozen_cmd]}"
      PREPARE_CMD="rm -rf node_modules .yarn/cache .pnp.* && ${config[prepare_cmd]}"
      NOTE="${config[note]} - lockfile only (frozen/ci)"
      ;;
    cache_only)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[offline_cmd]}"
      PREPARE_CMD="rm -rf node_modules .yarn/cache .pnp.*"
      NOTE="${config[note]} - cache only"
      ;;
    node_modules_only)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[install_cmd]}"
      PREPARE_CMD="rm -rf package-lock.json yarn.lock pnpm-lock.yaml && ${config[prepare_cmd]}"
      NOTE="${config[note]} - node_modules only"
      ;;
    node_modules_lockfile)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[frozen_cmd]}"
      PREPARE_CMD="rm -rf .yarn/cache .pnp.* && ${config[prepare_cmd]}"
      NOTE="${config[note]} - node_modules + lockfile"
      ;;
    node_modules_cache)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[offline_cmd]}"
      PREPARE_CMD="rm -rf package-lock.json yarn.lock pnpm-lock.yaml"
      NOTE="${config[note]} - node_modules + cache"
      ;;
    lockfile_cache)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[lockfile_cache_cmd]}"
      PREPARE_CMD="rm -rf node_modules .yarn/cache .pnp.*"
      NOTE="${config[note]} - lockfile + cache"
      ;;
    node_modules_lockfile_cache)
      INITIAL_CMD="${config[install_cmd]}"
      INSTALL_CMD="${config[install_cmd]}"
      PREPARE_CMD="${config[prepare_cmd]}"
      NOTE="${config[note]} - node_modules + lockfile + cache"
      ;;
  esac

  # Initial full install to populate files for non-clean scenarios
  if [ "$scenario" != "clean" ]; then
    echo "Initial full install before scenario $scenario"
    bash -c "$INITIAL_CMD"
  fi

  # Hyperfine
  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
            --prepare "$PREPARE_CMD" \
            --export-json /tmp/hyperfine_${manager}_${scenario}.json \
            --show-output \
            --ignore-failure \
            "bash -c '$INSTALL_CMD'"

  local disk_dir="${config[disk_dir]}"
  if [ "$manager" = "yarn-berry" ] && [ ! -d node_modules ]; then
    disk_dir=".yarn/cache"
  fi
  disk_usage=$(du -sh "$disk_dir" 2>/dev/null | cut -f1 || echo "N/A")

  repo_name=$(basename "$REPO_URL" .git)
  timestamp=$(date +"%Y%m%d_%H%M%S")
  result_file="$RESULTS_DIR/benchmark_${manager}_${scenario}_${repo_name}_${timestamp}.json"

  cat > "$result_file" <<EOF
{
  "repo_url": "$REPO_URL",
  "project_key": "medium",
  "manager": "$manager",
  "scenario": "$scenario",
  "timestamp": "$(date -Iseconds)",
  "hyperfine_runs": $RUNS,
  "hyperfine_warmup": $WARMUP,
  "time": $(jq '.results[0] // "N/A (failed)"' /tmp/hyperfine_${manager}_${scenario}.json),
  "disk_usage": "$disk_usage",
  "note": "$NOTE"
}
EOF

  echo "Benchmark for $manager - $scenario completed."
  echo "Result saved to: $result_file"
}

# Package manager configurations
# npm
declare -A npm_config
npm_config[version]="11.10"
npm_config[install_cmd]="npm install --force --legacy-peer-deps"
npm_config[frozen_cmd]="npm install --force --legacy-peer-deps"  # npm ci fails on peer deps in this project
npm_config[offline_cmd]="npm install --prefer-offline --force --legacy-peer-deps"
npm_config[lockfile_cache_cmd]="npm install --prefer-offline --force --legacy-peer-deps"
npm_config[prepare_cmd]="npm cache clean --force"
npm_config[disk_dir]="node_modules"
npm_config[note]="npm v${npm_config[version]}"
npm_config[activate_cmd]="npm install -g npm@${npm_config[version]}"

# yarn
declare -A yarn_classic_config
yarn_classic_config[version]="yarn@1.22.22"
yarn_classic_config[install_cmd]="yarn install --force --registry https://registry.npmjs.org"
yarn_classic_config[frozen_cmd]="yarn install --frozen-lockfile --force"
yarn_classic_config[offline_cmd]="yarn install --offline --force"
yarn_classic_config[lockfile_cache_cmd]="yarn install --offline --frozen-lockfile --force"
yarn_classic_config[prepare_cmd]="yarn cache clean"
yarn_classic_config[disk_dir]="node_modules"
yarn_classic_config[note]="Yarn Classic (${yarn_classic_config[version]})"
yarn_classic_config[activate_cmd]="corepack prepare yarn@1 --activate"

# berry
declare -A yarn_berry_config
yarn_berry_config[version]="yarn@4.12.0"
yarn_berry_config[install_cmd]="yarn install"
yarn_berry_config[frozen_cmd]="yarn install --immutable"
yarn_berry_config[offline_cmd]="yarn install --immutable-cache"
yarn_berry_config[lockfile_cache_cmd]="yarn install --immutable-cache"
yarn_berry_config[prepare_cmd]="yarn cache clean"
yarn_berry_config[disk_dir]="node_modules"
yarn_berry_config[note]="Yarn Berry (${yarn_berry_config[version]}, node-modules mode)"
yarn_berry_config[activate_cmd]="corepack prepare yarn@stable --activate"

# pnpm
declare -A pnpm_config
pnpm_config[version]="pnpm@10.28.2"
pnpm_config[install_cmd]="pnpm install --no-frozen-lockfile"
pnpm_config[frozen_cmd]="pnpm install --frozen-lockfile"
pnpm_config[offline_cmd]="pnpm install --offline"
pnpm_config[lockfile_cache_cmd]="pnpm install --offline --frozen-lockfile"
pnpm_config[prepare_cmd]="pnpm store prune"
pnpm_config[disk_dir]="node_modules"
pnpm_config[note]="pnpm (${pnpm_config[version]})"
pnpm_config[activate_cmd]="corepack prepare pnpm@latest --activate"

# Active managers and scenarios
ACTIVE_MANAGERS=(
  "npm"
  "yarn-classic"
  "yarn-berry"
  "pnpm"
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

# Run benchmarks
for manager in "${ACTIVE_MANAGERS[@]}"; do
  case "$manager" in
    npm) config_name="npm_config" ;;
    yarn-classic) config_name="yarn_classic_config" ;;
    yarn-berry) config_name="yarn_berry_config" ;;
    pnpm) config_name="pnpm_config" ;;
  esac

  for scenario in "${ACTIVE_SCENARIOS[@]}"; do
    run_benchmark "$manager" "$scenario" "$config_name"
  done
done

echo "All benchmarks completed!"
