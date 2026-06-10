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
  aube: '#64748b',
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
const useBoxPlotCpu = ref<boolean>(false)

const benchmarkItems = computed(() => {
  return (
    store.benchmarks?.map((b) => ({
      label: `${b.projectKey} — ${new Date(b.startTime).toLocaleDateString('pl-PL')} ${new Date(
        b.startTime,
      ).toLocaleTimeString('pl-PL', {
        hour: '2-digit',
        minute: '2-digit',
      })}`,
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

function getMedian(values: number[]): number {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid]
}

function getMean(values: number[]): number {
  if (values.length === 0) return 0
  const sum = values.reduce((a, b) => a + b, 0)
  return sum / values.length
}

function getFilteredTimesArray(entry: any): number[] | null {
  const times = entry?.time?.times
  const codes = entry?.time?.exit_codes

  if (!(Array.isArray(times) && times.length)) return null

  if (!Array.isArray(codes)) return times as number[]

  const validTimes = times.filter((_, index) => codes[index] === 0)

  return validTimes.length > 0 ? (validTimes as number[]) : null
}

function getFilteredMemoryArray(entry: any): number[] | null {
  const arr = entry?.time?.memory_usage_byte
  const codes = entry?.time?.exit_codes

  if (!(Array.isArray(arr) && arr.length)) return null

  const validArr = Array.isArray(codes)
    ? arr.filter((_, index) => codes[index] === 0)
    : arr

  if (validArr.length === 0) return null

  return validArr.map((b: number) => Math.round(b / 1024 / 1024))
}

function getBarTimeMedian(entry: any): number | null {
  const codes = entry?.time?.exit_codes
  let hasValidRuns = true

  if (Array.isArray(codes)) {
    hasValidRuns = codes.some((c: number) => c === 0)
  }

  // Zwracamy null jeśli wszystkie zakończyły się błędem
  if (!hasValidRuns) return null

  if (typeof entry?.time?.median === 'number') {
    return entry.time.median
  }

  const validTimes = getFilteredTimesArray(entry)
  return validTimes ? getMedian(validTimes) : null
}

function getDiskArray(entry: any): number[] | null {
  const validTimes = getFilteredTimesArray(entry)
  if (!validTimes) return null

  const val = parseDiskUsage(entry?.disk_usage)
  return val === null ? null : [val]
}

function getCpuArray(entry: any): number[] | null {
  const validTimes = getFilteredTimesArray(entry)
  if (!validTimes) return null

  const val = entry?.cpu_usage_percent
  return typeof val === 'number' ? [val] : null
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

const timeBoxDatasets = computed(() => makeBoxDatasets(getFilteredTimesArray))
const timeBarDatasets = computed(() => makeBarDatasets(getBarTimeMedian))

const diskBoxDatasets = computed(() => makeBoxDatasets(getDiskArray))
const diskBarDatasets = computed(() =>
  makeBarDatasets((e) => {
    const validTimes = getFilteredTimesArray(e)
    if (!validTimes) return null
    return parseDiskUsage(e?.disk_usage)
  }),
)

const memoryBoxDatasets = computed(() =>
  makeBoxDatasets(getFilteredMemoryArray),
)
const memoryBarDatasets = computed(() =>
  makeBarDatasets((e) => {
    const arr = getFilteredMemoryArray(e)
    return arr?.length ? getMean(arr) : null
  }),
)

const cpuBoxDatasets = computed(() => makeBoxDatasets(getCpuArray))
const cpuBarDatasets = computed(() =>
  makeBarDatasets((e) => {
    const validTimes = getFilteredTimesArray(e)
    if (!validTimes) return null
    return typeof e?.cpu_usage_percent === 'number' ? e.cpu_usage_percent : null
  }),
)

let timeChart: Chart | null = null
let diskChart: Chart | null = null
let memoryChart: Chart | null = null
let cpuChart: Chart | null = null

const timeChartRef = ref<HTMLCanvasElement | null>(null)
const diskChartRef = ref<HTMLCanvasElement | null>(null)
const memoryChartRef = ref<HTMLCanvasElement | null>(null)
const cpuChartRef = ref<HTMLCanvasElement | null>(null)

type ChartMetric = 'time' | 'disk' | 'memory' | 'cpu'

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
        : metric === 'cpu'
          ? useBoxPlotCpu.value
          : useBoxPlotMemory.value

  const yLabel =
    metric === 'time' ? 'Czas (s)' : metric === 'cpu' ? 'CPU (%)' : 'MB'

  const tickFont = { size: 16, weight: 'bold' }
  const titleFont = { size: 20, weight: 'bold' }
  const legendFont = { size: 16, weight: 'bold' }
  const textColor = '#000000'

  if (useBox) {
    const datasetsMap: Record<ChartMetric, BoxDataset[]> = {
      time: timeBoxDatasets.value,
      disk: diskBoxDatasets.value,
      memory: memoryBoxDatasets.value,
      cpu: cpuBoxDatasets.value,
    }
    const scenarioFnMap: Record<ChartMetric, (s: string) => BoxDataset[]> = {
      time: (s) =>
        makeBoxScenarioDatasets(s, 'Czas (s)', getFilteredTimesArray),
      disk: (s) => makeBoxScenarioDatasets(s, 'Dysk (MB)', getDiskArray),
      memory: (s) =>
        makeBoxScenarioDatasets(s, 'Pamięć (MB)', getFilteredMemoryArray),
      cpu: (s) => makeBoxScenarioDatasets(s, 'CPU (%)', getCpuArray),
    }
    const datasets = isAll ? datasetsMap[metric] : scenarioFnMap[metric](scen)

    return new Chart(ctx as any, {
      type: 'boxplot' as any,
      data: { labels, datasets } as any,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        color: textColor,
        plugins: {
          legend: {
            display: isAll,
            position: 'top',
            labels: {
              font: legendFont,
              color: textColor,
            },
          },
          tooltip: { mode: 'index', intersect: false },
        },
        scales: {
          x: {
            ticks: {
              autoSkip: false,
              maxRotation: 45,
              font: tickFont,
              color: textColor,
            },
          },
          y: {
            beginAtZero: true,
            ticks: {
              font: tickFont,
              color: textColor,
            },
            title: {
              display: true,
              text: yLabel,
              font: titleFont,
              color: textColor,
            },
          },
        },
      } as any,
    }) as Chart
  }

  const datasetsMap: Record<ChartMetric, BarDataset[]> = {
    time: timeBarDatasets.value,
    disk: diskBarDatasets.value,
    memory: memoryBarDatasets.value,
    cpu: cpuBarDatasets.value,
  }
  const scenarioFnMap: Record<ChartMetric, (s: string) => BarDataset[]> = {
    time: (s) => makeBarScenarioDatasets(s, 'Czas (s)', getBarTimeMedian),
    disk: (s) =>
      makeBarScenarioDatasets(s, 'Dysk (MB)', (e) => {
        const valid = getFilteredTimesArray(e)
        return valid ? parseDiskUsage(e?.disk_usage) : null
      }),
    memory: (s) =>
      makeBarScenarioDatasets(s, 'Pamięć (MB)', (e) => {
        const arr = getFilteredMemoryArray(e)
        return arr?.length ? getMean(arr) : null
      }),
    cpu: (s) =>
      makeBarScenarioDatasets(s, 'CPU (%)', (e) => {
        const valid = getFilteredTimesArray(e)
        return valid && typeof e?.cpu_usage_percent === 'number'
          ? e.cpu_usage_percent
          : null
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
      color: textColor,
      plugins: {
        legend: {
          display: isAll,
          position: 'top' as const,
          labels: {
            font: legendFont,
            color: textColor,
          },
        },
        tooltip: { mode: 'index', intersect: false },
      },
      scales: {
        x: {
          stacked: false,
          ticks: {
            autoSkip: false,
            maxRotation: 45,
            font: tickFont,
            color: textColor,
          },
        },
        y: {
          beginAtZero: metric !== 'disk',
          ...(metric === 'disk' ? { min: diskMin } : {}),
          ticks: {
            font: tickFont,
            color: textColor,
          },
          title: {
            display: true,
            text: yLabel,
            font: titleFont,
            color: textColor,
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
  if (cpuChart) cpuChart.destroy()

  timeChart = createChart(timeChartRef, 'time')
  diskChart = createChart(diskChartRef, 'disk')
  memoryChart = createChart(memoryChartRef, 'memory')
  cpuChart = createChart(cpuChartRef, 'cpu')
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
    useBoxPlotCpu,
  ],
  () => {
    nextTick(() => updateAllCharts())
  },
)

onBeforeUnmount(() => {
  if (timeChart) timeChart.destroy()
  if (diskChart) diskChart.destroy()
  if (memoryChart) memoryChart.destroy()
  if (cpuChart) cpuChart.destroy()
})
</script>

<template>
  <UContainer>
    <UCard class="mb-8">
      <template #header>
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold">Benchmarki menedżerów pakietów</h1>
          <UTabs v-if="benchmarkItems.length > 1" v-model="selectedFilename" :items="benchmarkItems"/>
          <span v-else class="text-sm text-gray-500">
            Projekt: {{ currentBenchmark?.projectKey }} | Run:
            {{
              currentBenchmark?.startTime ? new Date(currentBenchmark.startTime).toLocaleString('pl-PL', {
                dateStyle:
                    'short', timeStyle: 'short'
              }) : ''
            }}
          </span>
        </div>
      </template>

      <UTabs v-model="selectedView" :items="viewTabs" color="neutral" variant="link" :content="false"
             class="mb-6 w-full"/>

      <div class="flex flex-col gap-8">
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
                <USwitch v-model="useBoxPlotTime"/>
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="timeChartRef" class="w-full"/>
        </UCard>

        <UCard>
          <template #header>
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2">
                <span>Zużycie procesora (%)</span>
                <span v-if="useBoxPlotCpu" class="text-xs text-muted font-normal">
                  — pojedyncza wartość per run, pudełko zdegenerowane do linii
                </span>
              </div>
              <div class="flex items-center gap-2 shrink-0">
                <span class="text-sm text-muted">Słupkowy</span>
                <USwitch v-model="useBoxPlotCpu"/>
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="cpuChartRef" class="w-full"/>
        </UCard>

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
                <USwitch v-model="useBoxPlotDisk"/>
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="diskChartRef" class="w-full"/>
        </UCard>

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
                <USwitch v-model="useBoxPlotMemory"/>
                <span class="text-sm text-muted">Pudełkowy</span>
              </div>
            </div>
          </template>
          <canvas ref="memoryChartRef" class="w-full"/>
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
