ALL_LOCKFILES="package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock deno.lock vlt-lock.json cotton.lock"

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

  local delete_nm="rm -rf node_modules .pnp.*"
  local delete_lock="rm -rf $ALL_LOCKFILES"
  local delete_cache="rm -rf .yarn/cache && ${config[clean_cache_cmd]}"

  case "$scenario" in
    clean)
      INSTALL_CMD="${config[full_install]}"
      PREPARE_CMD="$delete_nm && $delete_lock && $delete_cache"
      ;;
    cache_only)
      INSTALL_CMD="${config[offline_install]}"
      PREPARE_CMD="$delete_nm && $delete_lock"
      ;;
    lockfile_only)
      INSTALL_CMD="${config[ci_install]}"
      PREPARE_CMD="$delete_nm && $delete_cache"
      ;;
    node_modules_only)
      INSTALL_CMD="${config[full_install]}"
      PREPARE_CMD="$delete_lock && $delete_cache"
      ;;
    lockfile_cache)
      INSTALL_CMD="${config[offline_ci_install]}"
      PREPARE_CMD="$delete_nm"
      ;;
    node_modules_cache)
      INSTALL_CMD="${config[offline_install]}"
      PREPARE_CMD="$delete_lock"
      ;;
    node_modules_lockfile)
      INSTALL_CMD="${config[ci_install]}"
      PREPARE_CMD="$delete_cache"
      ;;
    node_modules_lockfile_cache)
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
  local time_data
  time_data=$(jq '.results[0] // "N/A (failed)"' "/tmp/hyperfine_${manager}_${scenario}.json" 2>/dev/null || echo '"N/A (failed)"')

  cat > "/tmp/result_entry_${manager}_${scenario}.json" <<EOF
{
  "time": $time_data,
  "disk_usage": "$disk_usage",
  "note": "${config[note]} - $scenario"
}
EOF

  jq --arg manager "$manager" --arg scenario "$scenario" --slurpfile entry "/tmp/result_entry_${manager}_${scenario}.json" '
    .scenarios[$scenario][$manager] = $entry[0]
  ' "$RESULTS_JSON" > /tmp/tmp_results.json && mv /tmp/tmp_results.json "$RESULTS_JSON"

  rm -f "/tmp/result_entry_${manager}_${scenario}.json"

  echo "Wynik zapisany: $RESULTS_JSON (scenariusz: $scenario | narzędzie: $manager)"
}
