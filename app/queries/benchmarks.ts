export const ROOT_KEY = 'benchmarks' as const
export const KEYS = createCacheKeys(ROOT_KEY)

export const benchmarksList = defineQueryOptions(() => ({
  key: KEYS.list,
  query: async () => {
    return $fetch<BenchmarkResult[]>('/api/v1/benchmarks').catch((error) =>
      handleApiError(error, 'Wystąpił błąd podczas pobierania benchmarków'),
    )
  },
}))

// export const benchmarkById = defineQueryOptions(
//   ({ benchmarkId }: { benchmarkId: number }) => ({
//     key: KEYS.detailById(benchmarkId),
//     query: async () => {
//       return $fetch(`/api/benchmarks/${benchmarkId}`).catch((error) =>
//         handleApiError(
//           error,
//           'Wystąpił błąd podczas pobierania konkretnego benchmarku',
//         ),
//       )
//     },
//     enabled: Boolean(benchmarkId) && benchmarkId > 0,
//   }),
// )
