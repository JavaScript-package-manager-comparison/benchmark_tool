// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  modules: [
    '@nuxt/ui',
    '@pinia/colada-nuxt',
    '@pinia/nuxt',
    '@nuxt/image',
    '@nuxt/eslint',
    '@vueuse/nuxt',
  ],

  devtools: {
    enabled: true,
  },
  app: {
    head: {
      title: 'JavaScript Package Manager benchmark',
    },
  },

  css: ['~/assets/css/main.css'],

  experimental: {
    cookieStore: true,
  },

  compatibilityDate: '2025-01-15',

  eslint: { config: {} },
})
