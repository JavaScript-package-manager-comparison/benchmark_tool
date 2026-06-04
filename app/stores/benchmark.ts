import { benchmarksList } from '~/queries/benchmarks'

export const useBenchmarkStore = defineStore('benchmarkStore', () => {

  const { data: benchmarks, refresh: fetchBenchmarks } =
    useQuery(benchmarksList)

  return {
    benchmarks,
    fetchBenchmarks,
  }
})
