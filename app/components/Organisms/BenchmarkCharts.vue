<script setup lang="ts">
import Chart from 'chart.js/auto'

const store = useBenchmarkStore()

const toolColors: Record<string, string> = {
  npm: '#f43f5e',
  'yarn-classic': '#06b67f',
  pnpm: '#f59e0b',
  bun: '#8b5cf6',
  deno: '#70c7be',
  'yarn-berry': '#547d59',
  'yarn-zpm': '#ec4899',
  vlt: '#c026d3',
  cotton: '#3b82f6',
}

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

function parseDiskUsage(du: string | null): number | null {
  if (!du || du === 'N/A') return null
  const match = du.match(/([\d.]+)([KMG]?)/i)
  if (!match) return null
  let num = Number.parseFloat(match[1] ?? '')
  const unit = (match[2] || 'M').toUpperCase()
  if (unit === 'K') num /= 1024
  if (unit === 'G') num *= 1024
  return Math.round(num * 100) / 100
}

const selectedFilename = ref<string>('')
const selectedView = ref<string>('all')

const benchmarkItems = computed(() => {
  return (
    store.benchmarks?.map((b) => ({
      label: `${b.projectKey} — ${new Date(b.startTime).toLocaleDateString('pl-PL')} ${new Date(b.startTime).toLocaleTimeString('pl-PL', { hour: '2-digit', minute: '2-digit' })}`,
      value: b.filename,
    })) || []
  )
})

const currentBenchmark = computed(() => {
  return store.benchmarks?.find((b) => b.filename === selectedFilename.value)
})

const scenarios = computed(() => {
  if (!currentBenchmark.value) return []
  return Object.keys(currentBenchmark.value.data.scenarios)
})

const tools = computed(() => {
  if (!currentBenchmark.value) return []
  const allTools = new Set<string>()
  scenarios.value.forEach((scen) => {
    const scenarioData = currentBenchmark.value!.data.scenarios[scen]
    if (scenarioData) {
      Object.keys(scenarioData).forEach((tool) => allTools.add(tool))
    }
  })
  return Array.from(allTools)
})

const viewTabs = computed(() => [
  { label: 'Wszystkie scenariusze', value: 'all' },
  ...scenarios.value.map((scen) => ({
    label: scenarioLabels[scen] ?? scen,
    value: scen,
  })),
])

const timeDatasets = computed(() =>
  tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
      if (!entry) return null
      const t = entry.time?.mean
      return typeof t === 'number' ? t : null
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  })),
)

const diskDatasets = computed(() =>
  tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
      if (!entry) return null
      return parseDiskUsage(entry.disk_usage)
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  })),
)

const memoryDatasets = computed(() =>
  tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
      if (!entry) return null
      const memArray = entry.time?.memory_usage_byte
      return memArray?.length ? Math.round(memArray[0] / 1024 / 1024) : null
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  })),
)

interface ChartDataset {
  label: string
  data: (number | null)[]
  backgroundColor: string | string[]
  borderColor: string | string[]
  borderWidth: number
}

function getScenarioDatasets(
  type: 'time' | 'disk' | 'memory',
  scen: string,
): ChartDataset[] {
  const data = tools.value.map((tool) => {
    const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
    if (!entry) return null
    if (type === 'time') {
      const t = entry.time?.mean
      return typeof t === 'number' ? t : null
    }
    if (type === 'disk') return parseDiskUsage(entry.disk_usage)
    const memArray = entry.time?.memory_usage_byte
    return memArray?.length ? Math.round(memArray[0] / 1024 / 1024) : null
  })

  return [
    {
      label:
        type === 'time'
          ? 'Czas (s)'
          : type === 'disk'
            ? 'Dysk (MB)'
            : 'Pamięć (MB)',
      data,
      backgroundColor: tools.value.map((tool) => toolColors[tool] || '#64748b'),
      borderColor: tools.value.map((tool) => toolColors[tool] || '#64748b'),
      borderWidth: 2,
    },
  ]
}

function getDiskMin(datasets: ChartDataset[]): number {
  const allValues = datasets
    .flatMap((d) => d.data)
    .filter((v): v is number => typeof v === 'number')
  if (!allValues.length) return 0
  const min = Math.min(...allValues)
  const max = Math.max(...allValues)
  return Math.max(0, Math.floor(min - (max - min) * 0.5))
}

let timeChart: Chart | null = null
let diskChart: Chart | null = null
let memoryChart: Chart | null = null

const timeChartRef = ref<HTMLCanvasElement | null>(null)
const diskChartRef = ref<HTMLCanvasElement | null>(null)
const memoryChartRef = ref<HTMLCanvasElement | null>(null)

function createChart(
  canvasRef: Ref<HTMLCanvasElement | null>,
  type: 'time' | 'disk' | 'memory',
) {
  if (!canvasRef.value) return null
  const ctx = canvasRef.value.getContext('2d')
  if (!ctx) return null

  const isAll = selectedView.value === 'all'

  const labels = isAll ? scenarios.value : tools.value

  const allDatasetsMap: Record<'time' | 'disk' | 'memory', ChartDataset[]> = {
    time: timeDatasets.value,
    disk: diskDatasets.value,
    memory: memoryDatasets.value,
  }

  const datasets = isAll
    ? allDatasetsMap[type]
    : getScenarioDatasets(type, selectedView.value)

  const diskMin = type === 'disk' ? getDiskMin(datasets) : 0

  return new Chart(ctx, {
    type: 'bar',
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          display: isAll,
          position: 'top' as const,
        },
        tooltip: { mode: 'index', intersect: false },
      },
      scales: {
        x: { stacked: false, ticks: { autoSkip: false, maxRotation: 45 } },
        y: {
          beginAtZero: type !== 'disk',
          ...(type === 'disk' ? { min: diskMin } : {}),
          title: {
            display: true,
            text: type === 'time' ? 'Czas (s)' : 'MB',
          },
        },
      },
    },
  })
}

function updateAllCharts() {
  if (timeChart) timeChart.destroy()
  if (diskChart) diskChart.destroy()
  if (memoryChart) memoryChart.destroy()

  timeChart = createChart(timeChartRef, 'time')
  diskChart = createChart(diskChartRef, 'disk')
  memoryChart = createChart(memoryChartRef, 'memory')
}

onMounted(() => {
  if (benchmarkItems.value.length)
    selectedFilename.value = benchmarkItems.value[0]?.value ?? ''
  nextTick(() => updateAllCharts())
})

watch([selectedFilename, selectedView], () => {
  nextTick(() => updateAllCharts())
})

onBeforeUnmount(() => {
  if (timeChart) timeChart.destroy()
  if (diskChart) diskChart.destroy()
  if (memoryChart) memoryChart.destroy()
})
</script>

<template>
  <UContainer>
    <UCard class="mb-8">
      <template #header>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Benchmarki menedżerów pakietów</h1>
          <UTabs
              v-if="benchmarkItems.length > 1"
              v-model="selectedFilename"
              :items="benchmarkItems"
          />
          <span v-else class="text-sm text-gray-500">
            Projekt: {{ currentBenchmark?.projectKey }} | Run:
            {{ currentBenchmark?.startTime ? new Date(currentBenchmark.startTime).toLocaleString('pl-PL', { dateStyle: 'short', timeStyle: 'short' }) : '' }}
          </span>
        </div>
      </template>

      <UTabs
          v-model="selectedView"
          :items="viewTabs"
          color="neutral"
          variant="link"
          :content="false"
          class="mb-6 w-full"
      />

      <div class="flex flex-col gap-8">
        <UCard>
          <template #header>Prędkość instalacji (s)</template>
          <canvas ref="timeChartRef" class="w-full" />
        </UCard>

        <UCard>
          <template #header>Zajmowane miejsce na dysku (MB)</template>
          <canvas ref="diskChartRef" class="w-full" />
        </UCard>

        <UCard>
          <template #header>Zużycie pamięci RAM podczas instalacji (MB)</template>
          <canvas ref="memoryChartRef" class="w-full" />
        </UCard>
      </div>
    </UCard>
  </UContainer>
</template>

<style scoped>
canvas {
  height: 420px !important;
}
</style>