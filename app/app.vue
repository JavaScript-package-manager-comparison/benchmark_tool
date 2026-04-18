<script setup>
useHead({
  meta: [{ name: 'viewport', content: 'width=device-width, initial-scale=1' }],
  link: [{ rel: 'icon', href: '/favicon.ico' }],
  htmlAttrs: {
    lang: 'en',
  },
})

const title = 'JavaScript Package managers benchmark'
const description =
  'JavaScript Package Manager Testing with Benchmark Results Visualization.'

useSeoMeta({
  title,
  description,
  ogTitle: title,
  ogDescription: description,
})
</script>

<template>
  <UApp>
    <UHeader>
      <template #left>
        <NuxtLink to="/">
          <AtomsLogo />
        </NuxtLink>
      </template>

      <template #right>
        <UColorModeButton />

        <UButton
          to="https://github.com/JavaScript-package-manager-comparison"
          target="_blank"
          icon="i-simple-icons-github"
          aria-label="GitHub"
          color="neutral"
          variant="ghost"
        />
      </template>
    </UHeader>

    <UMain>
      <NuxtPage />
    </UMain>

    <UFooter>
      <template #left>
        <div class="flex-none space-y-2">
          <AtomsParagraphSmall text="Aplikacja została wykonana na" />
          <AtomsParagraphSmall :text="`Wydziale Informatyki Politechniki Białostockiej ${new Date().getFullYear()}`" class="text-primary-500" />
        </div>
      </template>

      <template #right>
        <UButton
          to="https://github.com/JavaScript-package-manager-comparison/benchmark_tool"
          target="_blank"
          icon="i-simple-icons-github"
          aria-label="GitHub"
          color="neutral"
          variant="ghost"
        />
      </template>
    </UFooter>
  </UApp>
</template>
