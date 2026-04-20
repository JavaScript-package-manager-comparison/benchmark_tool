import type { ToastProps } from '@nuxt/ui'

export default defineNuxtPlugin(() => {
  const createToast = (toastData: ToastProps) => {
    useToast().add(toastData)
  }

  const createErrorToast = (toastData: ToastProps) =>
    createToast({
      color: 'error',
      icon: 'i-mdi-exclamation-thick',
      ...toastData,
    })

  const createSuccessToast = (toastData: ToastProps) =>
    createToast({
      color: 'success',
      icon: 'i-mdi-check-circle-outline',
      ...toastData,
    })

  return {
    provide: {
      createToast,
      createErrorToast,
      createSuccessToast,
    },
  }
})
