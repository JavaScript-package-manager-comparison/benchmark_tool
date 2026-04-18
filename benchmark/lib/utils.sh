ALL_LOCKFILES="package-lock.json yarn.lock pnpm-lock.yaml bun.lockb deno.lock vlt-lock.json cotton.lock"
ALL_PM_ARTIFACTS=".yarn/cache .pnp.* .pnp.cjs .pnp.loader.mjs"
ALL_PM_CONFIGS=".yarnrc.yml vlt.json deno.json cotton.toml"

prepare_package_json() {
  local manager="$1"
  local version="$2"

  case "$manager" in
    pnpm)
      jq "del(.packageManager) | .packageManager = \"${version}\"" \
        package.json > tmp.json && mv tmp.json package.json
      ;;
    npm|deno|vlt|cotton)
      jq 'del(.packageManager, .pnpm)' \
        package.json > tmp.json && mv tmp.json package.json
      ;;
    *)
      jq "del(.packageManager, .pnpm) | .packageManager = \"${version}\"" \
        package.json > tmp.json && mv tmp.json package.json
      ;;
  esac
}

get_scenario_commands() {
  local scenario="$1"
  local manager="$2"

  case "$scenario" in
    # 1. Clean install
    clean)
      INITIAL_CMD="true" # skip initial install
      INSTALL_CMD="${config[full_install]}"
      PREPARE_CMD="rm -rf node_modules $ALL_LOCKFILES $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS && ${config[clean_cache_cmd]}"
      ;;

    # 2. Cache only
    cache_only)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[offline_install]}"
      PREPARE_CMD="rm -rf node_modules $ALL_LOCKFILES $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS"
      ;;

    # 3. Lockfile only
    lockfile_only)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[ci_install]}"
      PREPARE_CMD="rm -rf node_modules $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS && ${config[clean_cache_cmd]}"
      ;;

    # 4. node_modules only
    node_modules_only)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[full_install]}"
      PREPARE_CMD="rm -rf $ALL_LOCKFILES $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS && ${config[clean_cache_cmd]}"
      ;;

    # 5. Lockfile + cache
    lockfile_cache)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[offline_ci_install]}"
      PREPARE_CMD="rm -rf node_modules $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS"
      ;;

    # 6. Cache + node_modules
    node_modules_cache)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[offline_install]}"
      PREPARE_CMD="rm -rf $ALL_LOCKFILES $ALL_PM_ARTIFACTS $ALL_PM_CONFIGS"
      ;;

    # 7. Lockfile + node_modules
    node_modules_lockfile)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[ci_install]}"
      PREPARE_CMD="${config[clean_cache_cmd]}"
      ;;

    # 8. Cache + node_modules + lockfile
    node_modules_lockfile_cache)
      INITIAL_CMD="${config[full_install]}"
      INSTALL_CMD="${config[ci_install]}"
      PREPARE_CMD="true"
      ;;
  esac
}

save_result() {
  local manager="$1"
  local scenario="$2"
  local disk_dir="${config[disk_dir]}"

  if [[ "$manager" == "yarn-berry" || "$manager" == "yarn-zpm" ]] && [ ! -d node_modules ]; then
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
  "time": $(jq '.results[0] // "N/A (failed)"' "/tmp/hyperfine_${manager}_${scenario}.json" 2>/dev/null || echo '"N/A (failed)"'),
  "disk_usage": "$disk_usage",
  "note": "${config[note]} - $scenario"
}
EOF

  echo "Wynik zapisany: $result_file"
}
