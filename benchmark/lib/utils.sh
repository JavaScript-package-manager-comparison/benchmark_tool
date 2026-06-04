ALL_LOCKFILES="package-lock.json yarn.lock pnpm-lock.yaml bun.lockb bun.lock deno.lock vlt-lock.json cotton.lock aube-lock.yaml"

prepare_package_json() {
  local manager="$1"
  local version="$2"

  rm -f .npmrc

  case "$manager" in
    pnpm)
      jq "del(.packageManager) | .packageManager = \"${version}\"" \
        package.json > tmp.json && mv tmp.json package.json
      ;;
    npm|deno|vlt|cotton|aube)
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

  local delete_nm="find . -name 'node_modules' -type d -prune -exec rm -rf '{}' + 2>/dev/null || true && rm -rf .pnp.* .aube"
  local delete_lock="rm -rf $ALL_LOCKFILES"
  local delete_cache="rm -rf .yarn/cache && ${config[clean_cache_cmd]:-true}"

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

  if jq -e '.workspaces != null' package.json >/dev/null 2>&1 && { [ -d "packages" ] || [ -d "plugins" ]; }; then

    INSTALL_CMD="${INSTALL_CMD// --frozen-lockfile/}"
    INSTALL_CMD="${INSTALL_CMD// --immutable/}"
    INSTALL_CMD="${INSTALL_CMD// --frozen/}"
    if [[ "$INSTALL_CMD" == *"npm ci"* ]]; then
      INSTALL_CMD="${INSTALL_CMD/npm ci/npm install}"
    fi

    case "$manager" in
      aube)
        INSTALL_CMD="${INSTALL_CMD/aube ci/aube install}"
        ;;
      vlt)
        INSTALL_CMD="${INSTALL_CMD} --recursive"
        ;;
      yarn-zpm)
        yarn config set enableMigrationMode true 2>/dev/null || true
        ;;
    esac
  else
    if [[ "$manager" == "yarn-zpm" ]]; then
        yarn config set enableMigrationMode false 2>/dev/null || true
    fi
  fi
}

save_result() {
  local manager="$1"
  local scenario="$2"
  local disk_dir="${config[disk_dir]}"

  if [[ "$manager" == "yarn-berry" || "$manager" == "yarn-zpm" ]] && [ ! -d node_modules ]; then
    disk_dir=".yarn/cache"
  fi

  disk_usage=$(du -sh --exclude=.git . 2>/dev/null | cut -f1 || echo "N/A")

  local time_data
  time_data=$(jq '.results[0] // null' "/tmp/hyperfine_${manager}_${scenario}.json" 2>/dev/null || echo 'null')

  local cpu_usage
  cpu_usage=$(jq -r '
    if .results[0] != null and .results[0].mean > 0 then
      (((.results[0].user + .results[0].system) / .results[0].mean * 100) * 100 | round / 100)
    else
      "null"
    end
  ' "/tmp/hyperfine_${manager}_${scenario}.json" 2>/dev/null || echo 'null')

  jq -n \
    --argjson time_data "${time_data}" \
    --arg disk_usage "$disk_usage" \
    --argjson cpu "$cpu_usage" \
    --arg note "${config[note]} - $scenario" \
    '{
      time: (if $time_data == null then "N/A (failed)" else $time_data end),
      disk_usage: $disk_usage,
      cpu_usage_percent: $cpu,
      note: $note
    }' > "/tmp/result_entry_${manager}_${scenario}.json"

  jq --arg manager "$manager" --arg scenario "$scenario" --slurpfile entry "/tmp/result_entry_${manager}_${scenario}.json" '
    .scenarios[$scenario][$manager] = $entry[0]
  ' "$RESULTS_JSON" > /tmp/tmp_results.json && mv /tmp/tmp_results.json "$RESULTS_JSON"

  rm -f "/tmp/result_entry_${manager}_${scenario}.json"

  echo "Wynik zapisany: $RESULTS_JSON (scenariusz: $scenario | narzędzie: $manager | CPU: ${cpu_usage}%)"
}
