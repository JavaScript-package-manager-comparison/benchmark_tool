<script setup lang="ts">

</script>

<template>
  <UPageSection
      id="scenarios"
      title="Scenariusze instalacji w rzeczywistych warunkach"
      description="Aby dostarczyć najbardziej dokładny i sprawiedliwy benchmark menedżerów pakietów JavaScript (npm, Yarn, pnpm, Bun), przetestowaliśmy każdy z nich w tych 8 typowych stanach rzeczywistych. Każdy scenariusz był powtarzany wielokrotnie na identycznym sprzęcie."
      :features="[{
        icon: 'i-lucide-refresh-cw',
        title: 'Czysta instalacja',
        description: 'Całkowicie świeży katalog projektu — bez cache, bez lockfile, bez node_modules. Klasyczny benchmark cold-start.',
      }, {
        icon: 'i-lucide-file-lock',
        title: 'Tylko lockfile',
        description: 'Obecny jest wyłącznie plik lockfile (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock). Brak cache i node_modules.',
      }, {
        icon: 'i-lucide-database',
        title: 'Tylko cache',
        description: 'Istnieje tylko globalny cache pakietów. Brak lockfile i node_modules. Mierzy prędkość wypakowywania już pobranych pakietów.',
      }, {
        icon: 'i-lucide-folder',
        title: 'Tylko node_modules',
        description: 'Obecny jest wyłącznie folder node_modules z poprzedniej instalacji. Brak lockfile i cache.',
      }, {
        icon: 'i-lucide-folder-lock',
        title: 'node_modules + Lockfile',
        description: 'Istnieją zarówno folder node_modules, jak i plik lockfile. Testuje walidację lockfile oraz logikę minimalnej reinstalacji.',
      }, {
        icon: 'i-lucide-hard-drive',
        title: 'node_modules + Cache',
        description: 'Folder node_modules + zapełniony cache. Brak lockfile. Symuluje reinstalację z lokalnych modułów z cache’owanymi tarballami.',
      }, {
        icon: 'i-lucide-file-text',
        title: 'Lockfile + Cache',
        description: 'Dostępny jest zarówno lockfile, jak i cache. Brak node_modules. Najczęstszy scenariusz „ciepłej” instalacji w CI/CD.',
      }, {
        icon: 'i-lucide-zap',
        title: 'node_modules + Lockfile + Cache',
        description: 'Obecne są wszystkie trzy artefakty (node_modules + lockfile + cache). Absolutnie najszybsza możliwa reinstalacja.',
      }]"
  />
</template>
