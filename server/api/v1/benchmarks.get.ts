import fs from 'node:fs/promises'
import path from 'node:path'
import {defineEventHandler} from 'h3'

export default defineEventHandler(async () => {
  const resultsDir = path.resolve(process.cwd(), 'benchmark/results')

  try {
    const files = await fs.readdir(resultsDir)
    const jsonFiles = files
      .filter((file) => file.endsWith('.json'))
      .sort((a, b) => b.localeCompare(a))

    return await Promise.all(
      jsonFiles.map(async (filename) => {
        const filePath = path.join(resultsDir, filename)
        const raw = await fs.readFile(filePath, 'utf-8')
        const data = JSON.parse(raw)

        return {
          filename,
          startTime: data.start_time,
          repoUrl: data.repo_url,
          projectKey: data.project_key,
          data,
        }
      }),
    )
  } catch (err) {
    console.error('Nie udało się odczytać benchmarków:', err)
    throw createError({
      statusCode: 500,
      message: 'Nie udało się wczytać wyników benchmarków',
    })
  }
})
