import { benchmarksList } from '~/queries/benchmarks'

export const useBenchmarkStore = defineStore('benchmarkStore', () => {
  // const selectedBenchmarkId = ref()

  const { data: benchmarks, refresh: fetchBenchmarks } =
    useQuery(benchmarksList)
  // const { data: singleBenchmark, refresh: fetchBenchmarkById } = useQuery(() =>
  //   benchmarkById({
  //     benchmarkId: selectedBenchmarkId.value,
  //   }),
  // )

  return {
    benchmarks,
    // singleBenchmark,
    // selectedBenchmarkId,
    fetchBenchmarks,
    // fetchBenchmarkById,
  }
})
