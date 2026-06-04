export interface BenchmarkResult {
  filename: string
  startTime: string
  repoUrl: string
  projectKey: string
  data: {
    start_time: string
    repo_url: string
    project_key: string
    hyperfine_runs: number
    hyperfine_warmup: number
    scenarios: {
      [scenario: string]: {
        [packageManager: string]: {
          time: any
          disk_usage: string
          cpu_usage_percent: number | string | null
          note: string
        }
      }
    }
  }
}
