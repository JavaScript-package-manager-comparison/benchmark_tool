<script setup lang="ts">
</script>

<template>
  <UPageHero
      title="Benchmarki menedżerów pakietów"
      description="Kompleksowa analiza wydajności menedżerów pakietów JavaScript. Porównaj prędkości instalacji, zużycie miejsca na dysku oraz efektywność mechanizmów cachowania w różnych środowiskach projektowych."
      :links="[{
        label: 'Benchmarki',
        to: '/benchmarks',
        icon: 'i-lucide-table-2',
        size: 'xl',
      }, {
        label: 'Wykresy',
        to: 'charts',
        icon: 'i-simple-icons-chartdotjs',
        size: 'xl',
        color: 'neutral',
        variant: 'subtle',
      }]"
  />
</template>
