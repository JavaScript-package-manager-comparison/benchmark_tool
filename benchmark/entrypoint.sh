#!/bin/bash
set -euo pipefail

REPO_URLS=${REPO_URLS:-"https://github.com/JavaScript-package-manager-comparison/art-design-pro.git https://github.com/JavaScript-package-manager-comparison/metacubexd.git https://github.com/apache/superset.git"}
RUNS=${RUNS:-1}
WARMUP=${WARMUP:-1}
RESULTS_DIR=${RESULTS_DIR:-"/results"}

export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
export COREPACK_ENABLE_AUTO_PIN=0
export COREPACK_ENABLE_STRICT=0
export NPM_CONFIG_YES=true
export CI=true
export FORCE_COLOR=0
export NODE_OPTIONS="--max-old-space-size=8192"
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

mkdir -p "$RESULTS_DIR"

echo "=================================================================="
echo " Inicjalizacja badania"
echo " Repozytoria: $(echo "$REPO_URLS" | wc -w)"
echo " Menedżery pakietów: ${#ACTIVE_MANAGERS[@]}"
echo " Scenariusze:: ${#ACTIVE_SCENARIOS[@]}"
echo "=================================================================="

for REPO_URL in $REPO_URLS; do
  repo_name=$(basename "$REPO_URL" .git)
  project_dir="/project_${repo_name}"

  echo ""
  echo ">>> ROZPOCZYNAM BADANIE REPOZYTORIUM: $repo_name <<<"
  echo ""

  echo "Cloning repo: $REPO_URL into $project_dir"
  rm -rf "$project_dir"
  git clone --depth 1 "$REPO_URL" "$project_dir"
  cd "$project_dir"

  if [[ "$repo_name" == "superset" ]]; then
    cd superset-frontend

    jq '.private = true' package.json > tmp.json && mv tmp.json package.json

    jq '
      .overrides = (.overrides // {}) + {"dom-to-image": "2.6.0"} |
      .resolutions = (.resolutions // {}) + {"dom-to-image": "2.6.0"} |
      .pnpm = (.pnpm // {}) |
      .pnpm.overrides = (.pnpm.overrides // {}) + {"dom-to-image": "2.6.0"}
    ' package.json > tmp.json && mv tmp.json package.json

    while IFS= read -r file; do
      jq 'del(.dependencies["dom-to-pdf"], .devDependencies["dom-to-pdf"], .dependencies["dom-to-image-more"], .devDependencies["dom-to-image-more"])' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    done < <(find . -name "package.json" -not -path "*/node_modules/*")
  fi

  cp package.json package.json.original || true
  corepack enable >/dev/null 2>&1 || true

  global_timestamp=$(date +"%Y%m%d_%H%M%S")
  START_TIME=$(date -Iseconds)
  RESULTS_JSON="$RESULTS_DIR/${repo_name}_${global_timestamp}.json"

  project_key="unknown"
  [[ "$repo_name" == "art-design-pro" ]] && project_key="small"
  [[ "$repo_name" == "metacubexd" ]] && project_key="medium"
  [[ "$repo_name" == "superset" ]] && project_key="big"

  cat > "$RESULTS_JSON" <<EOF
{
  "start_time": "$START_TIME",
  "repo_url": "$REPO_URL",
  "project_key": "$project_key",
  "hyperfine_runs": $RUNS,
  "hyperfine_warmup": $WARMUP,
  "scenarios": {}
}
EOF

  echo "Wyniki dla $repo_name zostaną zapisane w: $RESULTS_JSON"

  for manager in "${ACTIVE_MANAGERS[@]}"; do
    for scenario in "${ACTIVE_SCENARIOS[@]}"; do
      run_benchmark "$manager" "$scenario"
    done
  done

  echo "=================================================================="
  echo " ZAKOŃCZONO BADANIE: $repo_name "
  echo " Wyniki: $RESULTS_JSON"
  echo "=================================================================="

  cd /
  rm -rf "$project_dir"

done

echo ""
echo "WSZYSTKIE BADANIA ZAKOŃCZONE POMYŚLNIE!"