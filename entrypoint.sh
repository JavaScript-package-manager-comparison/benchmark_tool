#!/bin/bash
set -e

# Default values
REPO_URL=${REPO_URL:-"https://github.com/JavaScript-package-manager-comparison/metacubexd.git"}
RUNS=${RUNS:-2}
WARMUP=${WARMUP:-1}
RESULTS_DIR=${RESULTS_DIR:-"/results"}

# Clone repository
echo "Cloning repo: $REPO_URL"
git clone --depth 1 "$REPO_URL" /project
cd /project

# package.json modification for compatibility
if [ -f package.json ]; then
  cp package.json package.json.bak
  jq 'del(.packageManager)' package.json > tmp.json && mv tmp.json package.json
  jq 'del(.pnpm)' package.json > tmp.json && mv tmp.json package.json
fi

corepack enable || true

# Package manager run
run_benchmark() {
  local manager="$1"
  declare -n config="$2"

  echo "=================================================================="
  echo "Starting benchmark for manager: $manager"
  echo "=================================================================="

  rm -rf node_modules .yarn/cache .pnp.* package-lock.json yarn.lock pnpm-lock.yaml .npm
  npm cache clean --force || true

  # Override packageManager field
  if [ -f package.json ]; then
    if [ "$manager" = "npm" ]; then
      jq 'del(.packageManager)' package.json > tmp.json && mv tmp.json package.json
    else
      jq ".packageManager = \"${config[version]}\"" package.json > tmp.json && mv tmp.json package.json
    fi
  fi

  # Activate manager
  if [ -n "${config[activate_cmd]}" ]; then
    eval "${config[activate_cmd]}"
  fi

  # Use node modules in yarn berry
  if [ "$manager" = "yarn-berry" ]; then
    echo "nodeLinker: node-modules" > .yarnrc.yml
  fi

  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
            --prepare "rm -rf node_modules .yarn/cache .pnp.* && ${config[prepare_cmd]}" \
            --export-json /tmp/hyperfine_${manager}.json \
            --show-output \
            "bash -c '${config[install_cmd]}'"

  disk_usage=$(du -sh "${config[disk_dir]}" 2>/dev/null | cut -f1 || echo "N/A")

  repo_name=$(basename "$REPO_URL" .git)
  timestamp=$(date +"%Y%m%d_%H%M%S")
  result_file="$RESULTS_DIR/benchmark_${manager}_clean_${repo_name}_${timestamp}.json"

  cat > "$result_file" <<EOF
{
  "repo_url": "$REPO_URL",
  "project_key": "medium",
  "manager": "$manager",
  "scenario": "clean_install",
  "timestamp": "$(date -Iseconds)",
  "hyperfine_runs": $RUNS,
  "hyperfine_warmup": $WARMUP,
  "time": $(jq '.results[0]' /tmp/hyperfine_${manager}.json),
  "disk_usage": "$disk_usage",
  "note": "${config[note]}"
}
EOF

  echo "Benchmark for $manager completed."
  echo "Result saved to: $result_file"
}

# Package manager configurations
# npm
declare -A npm_config
npm_config[version]="11.10"
npm_config[install_cmd]="npm install --force --legacy-peer-deps"
npm_config[prepare_cmd]="npm cache clean --force"
npm_config[disk_dir]="node_modules"
npm_config[note]="npm (${npm_config[version]})"
npm_config[activate_cmd]="npm install -g npm@${npm_config[version]}"

# yarn
declare -A yarn_classic_config
yarn_classic_config[version]="yarn@1.22.22"
yarn_classic_config[install_cmd]="yarn install --force --registry https://registry.npmjs.org"
yarn_classic_config[prepare_cmd]="yarn cache clean"
yarn_classic_config[disk_dir]="node_modules"
yarn_classic_config[note]="Yarn Classic (${yarn_classic_config[version]})"
yarn_classic_config[activate_cmd]="corepack prepare yarn@1 --activate"

# berry
declare -A yarn_berry_config
yarn_berry_config[version]="yarn@4.12.0"
yarn_berry_config[install_cmd]="yarn install"
yarn_berry_config[prepare_cmd]="yarn cache clean"
yarn_berry_config[disk_dir]="node_modules"
yarn_berry_config[note]="Yarn Berry (${yarn_berry_config[version]})"
yarn_berry_config[activate_cmd]="corepack prepare yarn@stable --activate"

# pnpm
declare -A pnpm_config
pnpm_config[version]="pnpm@10.28.2"
pnpm_config[install_cmd]="pnpm install --no-frozen-lockfile"
pnpm_config[prepare_cmd]="pnpm store prune"
pnpm_config[disk_dir]="node_modules"
pnpm_config[note]="pnpm (${pnpm_config[version]})"
pnpm_config[activate_cmd]="corepack prepare pnpm@latest --activate"

ACTIVE_MANAGERS=(
  "npm"
  "yarn-classic"
  "yarn-berry"
  "pnpm"
)

for manager in "${ACTIVE_MANAGERS[@]}"; do
  case "$manager" in
    npm) config_name="npm_config" ;;
    yarn-classic) config_name="yarn_classic_config" ;;
    yarn-berry) config_name="yarn_berry_config" ;;
    pnpm) config_name="pnpm_config" ;;
  esac

  run_benchmark "$manager" "$config_name"
done

echo "All benchmarks completed!"