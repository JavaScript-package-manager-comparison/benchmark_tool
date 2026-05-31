run_benchmark() {
  local manager="$1"
  local scenario="$2"

  echo ""
  echo "=================================================================="
  echo " BENCHMARK → $manager | $scenario"
  echo "=================================================================="
  echo ""

  rm -rf node_modules $ALL_LOCKFILES .pnp.* .yarn/cache .npm 2>/dev/null || true
  cp package.json.original package.json

  declare -n config="${manager//-/_}_config"

  prepare_package_json "$manager" "${config[version]}"

  if [ -n "${config[activate_cmd]}" ]; then
    echo "→ Aktywacja: ${config[activate_cmd]}"
    eval "${config[activate_cmd]}" || {
      echo "BŁĄD: Nie udało się aktywować $manager"
      return 1
    }
  fi

  case "$manager" in
    yarn-berry|yarn-zpm)
      yarn config set nodeLinker node-modules 2>/dev/null || true
      export YARN_ENABLE_IMMUTABLE_INSTALLS=false
      ;;
    deno)
      echo '{"nodeModulesDir": "auto"}' > deno.json
      ;;
    vlt)
      echo '{}' > vlt.json
      ;;
  esac

  get_scenario_commands "$scenario" "$manager"

  if [ "$scenario" != "clean" ]; then
    echo "→ Initial full install (setup)..."
    local attempt
    for attempt in {1..3}; do
      bash -c "${config[full_install]}" && break
      echo "  Próba $attempt nie powiodła się, ponawiam za 5s..."
      sleep 5
      eval "${config[clean_cache_cmd]}" 2>/dev/null || true
    done || {
      echo "BŁĄD: Initial install nie powiódł się dla $manager"
      return 1
    }
  fi

  echo "→ Uruchamianie hyperfine (runs=$RUNS, warmup=$WARMUP)..."
  echo "   INSTALL_CMD: $INSTALL_CMD"
  echo "   PREPARE_CMD: $PREPARE_CMD"

  hyperfine --warmup "$WARMUP" --runs "$RUNS" \
    --prepare "$PREPARE_CMD" \
    --export-json "/tmp/hyperfine_${manager}_${scenario}.json" \
    --show-output --ignore-failure \
    "bash -c '$INSTALL_CMD'" || true

  save_result "$manager" "$scenario"

  unset YARN_ENABLE_IMMUTABLE_INSTALLS 2>/dev/null || true
}
