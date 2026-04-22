<script setup lang="ts">
const packageManagers = [
  {
    title: 'npm',
    description:
      'Domyślny menedżer pakietów Node.js, najszerzej stosowany w ekosystemie JavaScript.',
    icon: 'i-simple-icons-npm',
    to: 'https://docs.npmjs.com',
    target: '_blank',
  },
  {
    title: 'Yarn Classic',
    description:
      'Pierwsza generacja Yarn — szybsza i bardziej deterministyczna alternatywa dla npm.',
    icon: 'i-lucide-package',
    to: 'https://classic.yarnpkg.com/docs',
    target: '_blank',
  },
  {
    title: 'Yarn Berry',
    description:
      "Yarn v2+ z obsługą Plug'n'Play eliminującą katalog node_modules.",
    icon: 'i-lucide-package',
    to: 'https://yarnpkg.com/getting-started',
    target: '_blank',
  },
  {
    title: 'pnpm',
    description:
      'Wydajny menedżer pakietów używający twardych dowiązań do współdzielenia zależności między projektami.',
    icon: 'i-simple-icons-pnpm',
    to: 'https://pnpm.io/motivation',
    target: '_blank',
  },
  {
    title: 'Bun',
    description:
      'Szybki all-in-one runtime JavaScript z wbudowanym, ultraszybkim menedżerem pakietów.',
    icon: 'i-simple-icons-bun',
    to: 'https://bun.sh/docs/cli/install',
    target: '_blank',
  },
  {
    title: 'Yarn ZPM',
    description:
      'Eksperymentalna gałąź Yarn skupiona na maksymalnej prędkości instalacji.',
    icon: 'i-lucide-zap',
    to: 'https://yarn6.netlify.app/',
    target: '_blank',
  },
  {
    title: 'Cotton',
    description:
      'Nowoczesny menedżer pakietów pisany w Rust, stawiający na minimalizm i prędkość.',
    icon: 'i-lucide-box',
    to: 'https://cotton.js.org/',
    target: '_blank',
  },
]
</script>

<template>
  <UPageSection>
    <UPageList divide>
      <UPageCard
          v-for="pm in packageManagers"
          :key="pm.title"
          :title="pm.title"
          :description="pm.description"
          :icon="pm.icon"
          :to="pm.to"
          :target="pm.target"
          variant="ghost"
          orientation="horizontal"
      />
    </UPageList>
  </UPageSection>
</template>