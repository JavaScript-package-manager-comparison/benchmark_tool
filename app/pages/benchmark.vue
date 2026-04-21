<script setup lang="ts">
import type { BadgeProps, TableColumn } from '@nuxt/ui'

const store = useBenchmarkStore()

const scenarioLabels: Record<string, string> = {
  clean: 'Clean install',
  lockfile_only: 'Lockfile only',
  cache_only: 'Cache only',
  node_modules_only: 'node_modules only',
  node_modules_lockfile: 'node_modules + Lockfile',
  node_modules_cache: 'node_modules + Cache',
  lockfile_cache: 'Lockfile + Cache',
  node_modules_lockfile_cache: 'node_modules + Lockfile + Cache',
}

const managerColors: Record<string, BadgeProps['color']> = {
  npm: 'error',
  'yarn-classic': 'info',
  'yarn-berry': 'info',
  pnpm: 'warning',
  bun: 'secondary',
  'yarn-zpm': 'primary',
  deno: 'neutral',
  vlt: 'error',
  cotton: 'success',
}

const activeBenchmarkIndex = ref(0)

const activeBenchmark = computed<BenchmarkResult | undefined>(() => {
  return store.benchmarks?.[activeBenchmarkIndex.value]
})

const benchmarkTabs = computed(() => {
  return (store.benchmarks ?? []).map((b: any, i: number) => ({
    label: b.projectKey ?? '???',
    value: String(i),
  }))
})

const scenarioTabs = computed(() => {
  const scenarios = activeBenchmark.value?.data?.scenarios ?? {}
  return Object.keys(scenarios).map((key) => ({
    label: scenarioLabels[key] ?? key,
    value: key,
  }))
})

const _activeScenario = ref('')
const activeScenario = computed({
  get: () => _activeScenario.value || scenarioTabs.value[0]?.value || '',
  set: (val) => {
    _activeScenario.value = val
  },
})

interface Row {
  manager: string
  mean: number
  memory_mb: number
  disk_usage: string
  exit_code: number
}

const rows = computed<Row[]>(() => {
  const scenario =
    activeBenchmark.value?.data?.scenarios?.[activeScenario.value]
  if (!scenario) return []

  return Object.entries(scenario).map(([manager, result]) => ({
    manager,
    mean: result.time?.mean ?? 0,
    memory_mb: Math.round(
      (result.time?.memory_usage_byte?.[0] ?? 0) / 1024 / 1024,
    ),
    disk_usage: result.disk_usage ?? 'N/A',
    exit_code: result.time?.exit_codes?.[0] ?? -1,
  }))
})

const fastestTime = computed(() =>
  rows.value.length > 0 ? Math.min(...rows.value.map((r) => r.mean)) : 0,
)

const columns: TableColumn<Row>[] = [
  { accessorKey: 'manager', header: 'Package manager' },
  { accessorKey: 'mean', header: 'Czas (s)' },
  { accessorKey: 'memory_mb', header: 'Pamięć (MB)' },
  { accessorKey: 'disk_usage', header: 'Dysk' },
  { accessorKey: 'exit_code', header: 'Status' },
]
</script>

<template>
  <div class="space-y-4 p-4">
    <h1 class="text-2xl font-bold">Benchmarki</h1>

    <UTabs
        v-if="store.benchmarks && store.benchmarks?.length > 1"
        :items="benchmarkTabs"
        :model-value="String(activeBenchmarkIndex)"
        color="neutral"
        variant="pill"
        :content="false"
        @update:model-value="activeBenchmarkIndex = Number($event)"
    />

    <UCard v-if="activeBenchmark">
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <UBadge :label="activeBenchmark.projectKey" color="primary" size="lg"/>
            <span class="text-sm text-muted">
              {{ new Date(activeBenchmark.startTime).toLocaleString('pl-PL') }}
            </span>
          </div>
          <div class="flex gap-4 text-xs text-muted">
            <span>Runs: <strong>{{ activeBenchmark.data.hyperfine_runs }}</strong></span>
            <span>Warmup: <strong>{{ activeBenchmark.data.hyperfine_warmup }}</strong></span>
          </div>
        </div>
      </template>

      <UButton
          :to="activeBenchmark.repoUrl"
          target="_blank"
          variant="link"
          icon="i-lucide-github"
          size="sm"
          :label="activeBenchmark.repoUrl"
          class="p-0"
      />
    </UCard>

    <UCard v-if="activeBenchmark">
      <template #header>
        <UTabs
            v-model="activeScenario"
            :items="scenarioTabs"
            color="neutral"
            variant="link"
            :content="false"
            class="w-full"
        />
      </template>

      <UTable :data="rows" :columns="columns">
        <template #manager-cell="{ row }">
          <UBadge
              :label="row.original.manager"
              :color="managerColors[row.original.manager] ?? 'neutral'"
              variant="subtle"
          />
        </template>

        <template #mean-cell="{ row }">
          <div class="flex items-center gap-2">
            <span :class="row.original.mean === fastestTime ? 'font-semibold text-success-500' : ''">
              {{ row.original.mean.toFixed(3) }}s
            </span>
            <UBadge
                v-if="row.original.mean === fastestTime"
                label="Najszybszy"
                color="success"
                variant="subtle"
                size="xs"
            />
          </div>
        </template>

        <template #memory_mb-cell="{ row }">
          {{ row.original.memory_mb }} MB
        </template>

        <template #disk_usage-cell="{ row }">
          <UBadge
              :label="row.original.disk_usage"
              :color="row.original.disk_usage === 'N/A' ? 'neutral' : 'info'"
              variant="outline"
              size="sm"
          />
        </template>

        <template #exit_code-cell="{ row }">
          <UBadge
              :label="row.original.exit_code === 0 ? 'OK' : `Exit ${row.original.exit_code}`"
              :color="row.original.exit_code === 0 ? 'success' : 'error'"
              variant="subtle"
              size="sm"
          />
        </template>
      </UTable>
    </UCard>
  </div>
</template>