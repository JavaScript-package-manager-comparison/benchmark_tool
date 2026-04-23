<script setup lang="ts">
import {
  BoxAndWiskers,
  BoxPlotController,
} from '@sgratzl/chartjs-chart-boxplot'
import { Chart } from 'chart.js/auto'

Chart.register(BoxPlotController, BoxAndWiskers)

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
const useBoxPlotTime = ref<boolean>(true)
const useBoxPlotDisk = ref<boolean>(false)
const useBoxPlotMemory = ref<boolean>(false)

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

interface BoxDataset {
  label: string
  data: (number[] | null)[]
  backgroundColor: string | string[]
  borderColor: string | string[]
  borderWidth: number
  itemRadius: number
  meanStyle: string
}

interface BarDataset {
  label: string
  data: (number | null)[]
  backgroundColor: string | string[]
  borderColor: string | string[]
  borderWidth: number
}

function getTimesArray(entry: any): number[] | null {
  const times = entry?.time?.times
  return Array.isArray(times) && times.length ? (times as number[]) : null
}

function getMemoryArray(entry: any): number[] | null {
  const arr = entry?.time?.memory_usage_byte
  if (!(Array.isArray(arr) && arr.length)) return null
  return arr.map((b: number) => Math.round(b / 1024 / 1024))
}

function getDiskArray(entry: any): number[] | null {
  const val = parseDiskUsage(entry?.disk_usage)
  return val === null ? null : [val]
}

function makeBoxDatasets(
  getValue: (entry: any) => number[] | null,
  alphaColor = true,
): BoxDataset[] {
  return tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
      return entry ? getValue(entry) : null
    }),
    backgroundColor: (toolColors[tool] || '#64748b') + (alphaColor ? '55' : ''),
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
    itemRadius: 3,
    meanStyle: 'triangle',
  }))
}

function makeBoxScenarioDatasets(
  scen: string,
  label: string,
  getValue: (entry: any) => number[] | null,
): BoxDataset[] {
  return [
    {
      label,
      data: tools.value.map((tool) => {
        const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
        return entry ? getValue(entry) : null
      }),
      backgroundColor: tools.value.map(
        (tool) => (toolColors[tool] || '#64748b') + '55',
      ),
      borderColor: tools.value.map((tool) => toolColors[tool] || '#64748b'),
      borderWidth: 2,
      itemRadius: 3,
      meanStyle: 'triangle',
    },
  ]
}

function makeBarDatasets(
  getValue: (entry: any) => number | null,
): BarDataset[] {
  return tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
      return entry ? getValue(entry) : null
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  }))
}

function makeBarScenarioDatasets(
  scen: string,
  label: string,
  getValue: (entry: any) => number | null,
): BarDataset[] {
  return [
    {
      label,
      data: tools.value.map((tool) => {
        const entry = currentBenchmark.value?.data.scenarios[scen]?.[tool]
        return entry ? getValue(entry) : null
      }),
      backgroundColor: tools.value.map((tool) => toolColors[tool] || '#64748b'),
      borderColor: tools.value.map((tool) => toolColors[tool] || '#64748b'),
      borderWidth: 2,
    },
  ]
}

function getDiskMin(datasets: BarDataset[]): number {
  const allValues = datasets
    .flatMap((d) => d.data)
    .filter((v): v is number => typeof v === 'number')
  if (!allValues.length) return 0
  const min = Math.min(...allValues)
  const max = Math.max(...allValues)
  return Math.max(0, Math.floor(min - (max - min) * 0.5))
}

const timeBoxDatasets = computed(() => makeBoxDatasets(getTimesArray))
const timeBarDatasets = computed(() =>
  makeBarDatasets((e) => {
    const t = e?.time?.mean
    return typeof t === 'number' ? t : null
  }),
)

const diskBoxDatasets = computed(() => makeBoxDatasets(getDiskArray))
const diskBarDatasets = computed(() =>
  makeBarDatasets((e) => parseDiskUsage(e?.disk_usage)),
)

const memoryBoxDatasets = computed(() => makeBoxDatasets(getMemoryArray))
const memoryBarDatasets = computed(() =>
  makeBarDatasets((e) => {
    const arr = e?.time?.memory_usage_byte
    return arr?.length ? Math.round(arr[0] / 1024 / 1024) : null
  }),
)

let timeChart: Chart | null = null
let diskChart: Chart | null = null
let memoryChart: Chart | null = null

const timeChartRef = ref<HTMLCanvasElement | null>(null)
const diskChartRef = ref<HTMLCanvasElement | null>(null)
const memoryChartRef = ref<HTMLCanvasElement | null>(null)

type ChartMetric = 'time' | 'disk' | 'memory'

function createChart(
  canvasRef: Ref<HTMLCanvasElement | null>,
  metric: ChartMetric,
) {
  if (!canvasRef.value) return null
  const ctx = canvasRef.value.getContext('2d')
  if (!ctx) return null

  const isAll = selectedView.value === 'all'
  const labels = isAll ? scenarios.value : tools.value
  const scen = selectedView.value

  const useBox =
    metric === 'time'
      ? useBoxPlotTime.value
      : metric === 'disk'
        ? useBoxPlotDisk.value
        : useBoxPlotMemory.value

  const yLabel = metric === 'time' ? 'Czas (s)' : 'MB'

  if (useBox) {
    const datasetsMap: Record<ChartMetric, BoxDataset[]> = {
      time: timeBoxDatasets.value,
      disk: diskBoxDatasets.value,
      memory: memoryBoxDatasets.value,
    }
    const scenarioFnMap: Record<ChartMetric, (s: string) => BoxDataset[]> = {
      time: (s) => makeBoxScenarioDatasets(s, 'Czas (s)', getTimesArray),
      disk: (s) => makeBoxScenarioDatasets(s, 'Dysk (MB)', getDiskArray),
      memory: (s) => makeBoxScenarioDatasets(s, 'Pamięć (MB)', getMemoryArray),
    }
    const datasets = isAll ? datasetsMap[metric] : scenarioFnMap[metric](scen)

    return new Chart(ctx as any, {
      type: 'boxplot' as any,
      data: { labels, datasets } as any,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: isAll, position: 'top' },
          tooltip: { mode: 'index', intersect: false },
        },
        scales: {
          x: { ticks: { autoSkip: false, maxRotation: 45 } },
          y: { beginAtZero: true, title: { display: true, text: yLabel } },
        },
      } as any,
    }) as Chart
  }
  const datasetsMap: Record<ChartMetric, BarDataset[]> = {
    time: timeBarDatasets.value,
    disk: diskBarDatasets.value,
    memory: memoryBarDatasets.value,
  }
  const scenarioFnMap: Record<ChartMetric, (s: string) => BarDataset[]> = {
    time: (s) =>
      makeBarScenarioDatasets(s, 'Czas (s)', (e) => {
        const t = e?.time?.mean
        return typeof t === 'number' ? t : null
      }),
    disk: (s) =>
      makeBarScenarioDatasets(s, 'Dysk (MB)', (e) =>
        parseDiskUsage(e?.disk_usage),
      ),
    memory: (s) =>
      makeBarScenarioDatasets(s, 'Pamięć (MB)', (e) => {
        const arr = e?.time?.memory_usage_byte
        return arr?.length ? Math.round(arr[0] / 1024 / 1024) : null
      }),
  }
  const datasets = isAll ? datasetsMap[metric] : scenarioFnMap[metric](scen)
  const diskMin = metric === 'disk' ? getDiskMin(datasets) : 0

  return new Chart(ctx, {
    type: 'bar',
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: isAll, position: 'top' as const },
        tooltip: { mode: 'index', intersect: false },
      },
      scales: {
        x: { stacked: false, ticks: { autoSkip: false, maxRotation: 45 } },
        y: {
          beginAtZero: metric !== 'disk',
          ...(metric === 'disk' ? { min: diskMin } : {}),
          title: { display: true, text: yLabel },
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

watch(
  [
    selectedFilename,
    selectedView,
    useBoxPlotTime,
    useBoxPlotDisk,
    useBoxPlotMemory,
  ],
  () => {
    nextTick(() => updateAllCharts())
  },
)

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
        <!-- Czas -->
        <UCard>
          <template #header>
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <span>Prędkość instalacji (s)</span>
                <span v-if="useBoxPlotTime" class="text-xs text-muted font-normal">
                  — pudełko = Q1–Q3, linia = mediana, trójkąt = średnia, wąsy = min/max
                </span>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span class="text-sm text-muted">Słupkowy</span>
                <USwitch v-model="useBoxPlotTime" />
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="timeChartRef" class="w-full" />
        </UCard>

        <!-- Dysk -->
        <UCard>
          <template #header>
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <span>Zajmowane miejsce na dysku (MB)</span>
                <span v-if="useBoxPlotDisk" class="text-xs text-muted font-normal">
                  — pojedyncza wartość per run, pudełko zdegenerowane do linii
                </span>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span class="text-sm text-muted">Słupkowy</span>
                <USwitch v-model="useBoxPlotDisk" />
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="diskChartRef" class="w-full" />
        </UCard>

        <!-- Pamięć -->
        <UCard>
          <template #header>
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <span>Zużycie pamięci RAM podczas instalacji (MB)</span>
                <span v-if="useBoxPlotMemory" class="text-xs text-muted font-normal">
                  — pudełko = Q1–Q3, linia = mediana, trójkąt = średnia, wąsy = min/max
                </span>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span class="text-sm text-muted">Słupkowy</span>
                <USwitch v-model="useBoxPlotMemory" />
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
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