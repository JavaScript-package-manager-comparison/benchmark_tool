<script setup lang="ts">
import type { BadgeProps, TableColumn } from '@nuxt/ui'
import type { SortingState } from '@tanstack/vue-table'
import { getSortedRowModel } from '@tanstack/vue-table'

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
  aube: 'neutral',
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

const sorting = ref<SortingState>([])

interface Row {
  manager: string
  isSuccess: boolean
  isMixed: boolean
  medianTime: number
  cpu_percent: number | string
  memory_mb: number
  disk_usage: string
  exit_code: number
}

function getMean(values: number[]): number {
  if (values.length === 0) return 0
  const sum = values.reduce((a, b) => a + b, 0)
  return sum / values.length
}

const rows = computed<Row[]>(() => {
  const scenario =
    activeBenchmark.value?.data?.scenarios?.[activeScenario.value]
  if (!scenario) return []

  return Object.entries(scenario).map(([manager, result]) => {
    const codes: number[] = result.time?.exit_codes || []

    const isSuccess =
      Array.isArray(codes)
      && codes.length > 0
      && codes.some((c: number) => c === 0)

    const isMixed = isSuccess && codes.some((c: number) => c !== 0)

    const finalExitCode =
      !isSuccess && codes.length > 0
        ? (codes.find((c: number) => c !== 0) ?? -1)
        : 0

    let medianTime = 0
    if (isSuccess && typeof result.time?.median === 'number') {
      medianTime = result.time.median
    }

    let memoryMb = 0
    const memArray: number[] = result.time?.memory_usage_byte || []
    if (
      isSuccess
      && Array.isArray(memArray)
      && memArray.length === codes.length
    ) {
      const validMems = memArray.filter((_val, idx) => codes[idx] === 0)
      if (validMems.length > 0) {
        memoryMb = Math.round(getMean(validMems) / 1024 / 1024)
      }
    }

    return {
      manager,
      isSuccess,
      isMixed,
      medianTime,
      cpu_percent:
        typeof result.cpu_usage_percent === 'number'
          ? result.cpu_usage_percent
          : 'N/A',
      memory_mb: memoryMb,
      disk_usage: result.disk_usage ?? 'N/A',
      exit_code: finalExitCode,
    }
  })
})

const fastestTime = computed(() => {
  const validRows = rows.value.filter((r) => r.isSuccess && r.medianTime > 0)
  return validRows.length > 0
    ? Math.min(...validRows.map((r) => r.medianTime))
    : 0
})

function sortIcon(column: any): string {
  if (column.getIsSorted() === 'asc') return 'i-lucide-arrow-up'
  if (column.getIsSorted() === 'desc') return 'i-lucide-arrow-down'
  return 'i-lucide-arrow-up-down'
}

const columns: TableColumn<Row>[] = [
  {
    accessorKey: 'manager',
    header: 'Package manager',
    enableSorting: true,
  },
  {
    accessorKey: 'medianTime',
    header: 'Czas (s)',
    enableSorting: true,
  },
  {
    accessorKey: 'cpu_percent',
    header: 'CPU (%)',
    enableSorting: true,
    sortingFn: (a, b) => {
      const va = a.original.cpu_percent
      const vb = b.original.cpu_percent
      if (va === 'N/A') return 1
      if (vb === 'N/A') return -1
      return (va as number) - (vb as number)
    },
  },
  {
    accessorKey: 'memory_mb',
    header: 'Pamięć (MB)',
    enableSorting: true,
  },
  {
    accessorKey: 'disk_usage',
    header: 'Dysk',
    enableSorting: true,
  },
  {
    accessorKey: 'exit_code',
    header: 'Status',
    enableSorting: true,
  },
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
            <UBadge :label="activeBenchmark.projectKey" color="primary" size="lg" />
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

      <UTable
          :data="rows"
          :columns="columns"
          v-model:sorting="sorting"
          :sorting-options="{ getSortedRowModel: getSortedRowModel() }"
      >
        <template #manager-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            Package manager
          </UButton>
        </template>

        <template #medianTime-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            Czas (s)
          </UButton>
        </template>

        <template #cpu_percent-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            CPU (%)
          </UButton>
        </template>

        <template #memory_mb-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            Pamięć (MB)
          </UButton>
        </template>

        <template #disk_usage-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            Dysk
          </UButton>
        </template>

        <template #exit_code-header="{ column }">
          <UButton variant="ghost" size="xs" :trailing-icon="sortIcon(column)" @click="column.toggleSorting()">
            Status
          </UButton>
        </template>

        <template #manager-cell="{ row }">
          <UBadge
              :label="row.original.manager"
              :color="managerColors[row.original.manager] ?? 'neutral'"
              variant="subtle"
          />
        </template>

        <template #medianTime-cell="{ row }">
          <div v-if="row.original.isSuccess" class="flex items-center gap-2">
            <span :class="row.original.medianTime === fastestTime ? 'font-semibold text-success-500' : ''">
              {{ row.original.medianTime.toFixed(3) }}s
            </span>
            <UBadge
                v-if="row.original.medianTime === fastestTime && row.original.medianTime > 0"
                label="Najszybszy"
                color="success"
                variant="subtle"
                size="xs"
            />
          </div>
          <span v-else class="text-sm text-gray-400">N/A</span>
        </template>

        <template #cpu_percent-cell="{ row }">
          <div v-if="row.original.isSuccess" class="flex items-center gap-2">
            <span :class="typeof row.original.cpu_percent === 'number' && row.original.cpu_percent > 100 ? 'font-semibold text-primary' : ''">
              {{ typeof row.original.cpu_percent === 'number' ? row.original.cpu_percent.toFixed(2) + '%' : row.original.cpu_percent }}
            </span>
          </div>
          <span v-else class="text-sm text-gray-400">N/A</span>
        </template>

        <template #memory_mb-cell="{ row }">
          <span v-if="row.original.isSuccess">{{ row.original.memory_mb }} MB</span>
          <span v-else class="text-sm text-gray-400">N/A</span>
        </template>

        <template #disk_usage-cell="{ row }">
          <UBadge
              v-if="row.original.isSuccess"
              :label="row.original.disk_usage"
              :color="row.original.disk_usage === 'N/A' ? 'neutral' : 'info'"
              variant="outline"
              size="sm"
          />
          <span v-else class="text-sm text-gray-400">N/A</span>
        </template>

        <template #exit_code-cell="{ row }">
          <UBadge
              v-if="row.original.isMixed"
              label="Warning"
              color="warning"
              variant="subtle"
              size="sm"
              title="Część instalacji zakończyła się błędem"
          />
          <UBadge
              v-else-if="row.original.isSuccess"
              label="OK"
              color="success"
              variant="subtle"
              size="sm"
          />
          <UBadge
              v-else
              :label="`Exit ${row.original.exit_code}`"
              color="error"
              variant="subtle"
              size="sm"
          />
        </template>
      </UTable>
    </UCard>
  </div>
</template>