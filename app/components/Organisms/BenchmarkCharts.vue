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

function parseDiskUsage(du: string | null): number | null {
  if (!du || du === 'N/A') return null
  const match = du.match(/([\d.]+)([KMG]?)/i)
  if (!match) return null
  let num = Number.parseFloat(match[1] ?? '')
  const unit = (match[2] || 'M').toUpperCase()
  if (unit === 'K') num /= 1024
  if (unit === 'G') num *= 1024
  return Math.round(num * 100) / 100 // MB
}

const selectedFilename = ref<string>('')

const benchmarkItems = computed(() => {
  return (
    store.benchmarks?.map((b) => ({
      label: `${b.projectKey} — ${new Date(b.startTime).toLocaleDateString(
        'pl-PL',
      )} ${new Date(b.startTime).toLocaleTimeString('pl-PL', {
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

const timeDatasets = computed(() => {
  return tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      if (
        !(
          currentBenchmark.value?.data.scenarios[scen]
          && currentBenchmark.value?.data.scenarios[scen][tool]
        )
      )
        return null
      const t = currentBenchmark.value.data.scenarios[scen][tool].time?.mean
      return typeof t === 'number' ? t : null
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  }))
})

const diskDatasets = computed(() => {
  return tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      if (
        !(
          currentBenchmark.value?.data.scenarios[scen]
          && currentBenchmark.value?.data.scenarios[scen][tool]
        )
      )
        return null
      const du = currentBenchmark.value.data.scenarios[scen][tool].disk_usage
      return parseDiskUsage(du)
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  }))
})

const memoryDatasets = computed(() => {
  return tools.value.map((tool) => ({
    label: tool,
    data: scenarios.value.map((scen) => {
      if (
        !(
          currentBenchmark.value?.data.scenarios[scen]
          && currentBenchmark.value?.data.scenarios[scen][tool]
        )
      )
        return null
      const memArray =
        currentBenchmark.value?.data.scenarios[scen][tool].time
          ?.memory_usage_byte
      return memArray && memArray.length
        ? Math.round(memArray[0] / 1024 / 1024)
        : null
    }),
    backgroundColor: toolColors[tool] || '#64748b',
    borderColor: toolColors[tool] || '#64748b',
    borderWidth: 2,
  }))
})

let timeChart: Chart | null = null
let diskChart: Chart | null = null
let memoryChart: Chart | null = null

const timeChartRef = ref<HTMLCanvasElement | null>(null)
const diskChartRef = ref<HTMLCanvasElement | null>(null)
const memoryChartRef = ref<HTMLCanvasElement | null>(null)

interface ChartDataset {
  label: string
  data: (number | null)[]
  backgroundColor: string
  borderColor: string
  borderWidth: number
}

function createChart(
  canvasRef: Ref<HTMLCanvasElement | null>,
  type: 'time' | 'disk' | 'memory',
) {
  if (!canvasRef.value) return null

  const ctx = canvasRef.value.getContext('2d')
  if (!ctx) return null

  const labels = scenarios.value

  const datasetsMap: Record<'time' | 'disk' | 'memory', ChartDataset[]> = {
    time: timeDatasets.value,
    disk: diskDatasets.value,
    memory: memoryDatasets.value,
  }
  const datasets = datasetsMap[type]

  return new Chart(ctx, {
    type: 'bar',
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'top' as const },
        tooltip: { mode: 'index', intersect: false },
      },
      scales: {
        x: {
          stacked: false,
          ticks: { autoSkip: false, maxRotation: 45 },
        },
        y: {
          beginAtZero: type !== 'disk',
          min:
            type === 'disk'
              ? (() => {
                  const allValues = datasets
                    .flatMap((ds: ChartDataset) => ds.data)
                    .filter((v): v is number => typeof v === 'number')
                  const maxValue = allValues.length
                    ? Math.max(...allValues)
                    : 1000
                  return Math.floor(maxValue * 0.5) // dokładnie pół największej wartości – różnice widoczne
                })()
              : 0,
          title: {
            display: true,
            text: type === 'time' ? 'Czas (s)' : type === 'disk' ? 'MB' : 'MB',
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

  nextTick(() => {
    updateAllCharts()
  })
})

watch(selectedFilename, () => {
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
          <h1 class="text-2xl font-bold">Benchmarki menedżerów
            pakietów</h1>
          <UTabs
              v-if="benchmarkItems.length > 1"
              v-model="selectedFilename"
              :items="benchmarkItems"
          />
          <span v-else class="text-sm text-gray-500">Projekt: {{
              currentBenchmark?.projectKey
            }} | Run: {{
              currentBenchmark?.startTime ?
                  new Date(currentBenchmark.startTime).toLocaleString('pl-PL', {
                    dateStyle: 'short', timeStyle: 'short'
                  }) : ''
            }}</span>
        </div>
      </template>

      <div class="flex flex-col gap-8">
        <UCard>
          <template #header>Prędkość instalacji
            (s)
          </template>
          <canvas ref="timeChartRef" class="w-full"/>
        </UCard>

        <UCard>
          <template #header>Zajmowane miejsce na dysku
            (MB)
          </template>
          <canvas ref="diskChartRef" class="w-full"/>
        </UCard>

        <UCard>
          <template #header>Zużycie pamięci RAM podczas instalacji
            (MB)
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