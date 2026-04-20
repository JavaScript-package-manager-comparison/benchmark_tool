import type { FormError } from '@nuxt/ui'
import type { FetchError } from 'ofetch'
import type { ZodError } from 'zod'

export function handleValidationError(
  error: ZodError | undefined,
): FormError[] {
  if (!error) return []
  return error?.issues.map((e) => {
    return {
      name: e.path[0] as string,
      message: e.message,
    }
  })
}

export function handleApiError(error: unknown, title: string) {
  console.error('Unexpected error:', error)
  const statusMessage =
    (error as FetchError)?.data?.statusMessage
    || (error as Error)?.message
    || `${error}`

  useNuxtApp().$createErrorToast({
    title,
    description: statusMessage,
  })
}
