#!/bin/bash
set -e

# Default values
REPO_URL=${REPO_URL:-"https://github.com/JavaScript-package-manager-comparison/metacubexd.git"}
RUNS=${RUNS:-3}
WARMUP=${WARMUP:-1}
RESULTS_DIR=${RESULTS_DIR:-"/results"}

# Package manager versions
NPM_VERSION="11.10"
YARN_CLASSIC_VERSION="yarn@1.22.22"
YARN_BERRY_VERSION="yarn@4.12.0"
PNPM_VERSION="pnpm@10.28.2"

# List of package managers
MANAGERS=("npm" "yarn-classic" "yarn-berry" "pnpm")

# Clone repository
echo "Cloning repo: $REPO_URL"
git clone --depth 1 "$REPO_URL" /project
cd /project

# Modify package.json for compatibility with other managers
if [ -f package.json ]; then
  cp package.json package.json.bak
  jq 'del(.packageManager)' package.json > tmp.json && mv tmp.json package.json
  jq 'del(.pnpm)' package.json > tmp.json && mv tmp.json package.json
fi

corepack enable || true

for MANAGER in "${MANAGERS[@]}"; do
  echo "=================================================================="
  echo "Starting benchmark for manager: $MANAGER"
  echo "=================================================================="

  rm -rf node_modules .yarn/cache .pnp.* package-lock.json yarn.lock pnpm-lock.yaml .npm
  npm cache clean --force || true

  # Override packageManager field in package.json with current package manager
  if [ -f package.json ]; then
    case "$MANAGER" in
      npm)
        jq 'del(.packageManager)' package.json > tmp.json && mv tmp.json package.json
        NOTE="npm v$NPM_VERSION"
        ;;
      yarn-classic)
        jq ".packageManager = \"$YARN_CLASSIC_VERSION\"" package.json > tmp.json && mv tmp.json package.json
        NOTE="Yarn Classic ($YARN_CLASSIC_VERSION)"
        ;;
      yarn-berry)
        jq ".packageManager = \"$YARN_BERRY_VERSION\"" package.json > tmp.json && mv tmp.json package.json
        NOTE="Yarn Berry ($YARN_BERRY_VERSION)"
        ;;
      pnpm)
        jq ".packageManager = \"$PNPM_VERSION\"" package.json > tmp.json && mv tmp.json package.json
        NOTE="pnpm ($PNPM_VERSION)"
        ;;
    esac
  fi

  # Manager commands
  case "$MANAGER" in
    npm)
      npm install -g npm@$NPM_VERSION
      INSTALL_CMD="npm install --force --legacy-peer-deps"
      DISK_DIR="node_modules"
      PREPARE_CMD="npm cache clean --force"
      ;;
    yarn-classic)
      corepack prepare yarn@1 --activate
      INSTALL_CMD="yarn install --force"
      DISK_DIR="node_modules"
      PREPARE_CMD="yarn cache clean"
      ;;
    yarn-berry)
      corepack prepare yarn@stable --activate
      echo "nodeLinker: node-modules" > .yarnrc.yml # force node modules due to workspace issues
      INSTALL_CMD="yarn install"
      DISK_DIR="node_modules"
      PREPARE_CMD="yarn cache clean"
      ;;
    pnpm)
      corepack prepare pnpm@latest --activate
      INSTALL_CMD="pnpm install --no-frozen-lockfile"
      DISK_DIR="node_modules"
      PREPARE_CMD="pnpm store prune"
      ;;
  esac

  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
            --prepare "rm -rf node_modules .yarn/cache .pnp.* && $PREPARE_CMD" \
            --export-json /tmp/hyperfine_${MANAGER}.json \
            --show-output \
            "bash -c '$INSTALL_CMD'"

  disk_usage=$(du -sh "$DISK_DIR" 2>/dev/null | cut -f1 || echo "N/A")

  repo_name=$(basename "$REPO_URL" .git)
  timestamp=$(date +"%Y%m%d_%H%M%S")
  result_file="$RESULTS_DIR/benchmark_${MANAGER}_clean_${repo_name}_${timestamp}.json"

  cat > "$result_file" <<EOF
{
  "repo_url": "$REPO_URL",
  "project_key": "medium",
  "manager": "$MANAGER",
  "scenario": "clean_install",
  "timestamp": "$(date -Iseconds)",
  "hyperfine_runs": $RUNS,
  "hyperfine_warmup": $WARMUP,
  "time": $(jq '.results[0]' /tmp/hyperfine_${MANAGER}.json),
  "disk_usage": "$disk_usage",
  "note": "$NOTE"
}
EOF

  echo "Benchmark for $MANAGER completed."
done

echo "All benchmarks completed!"