<script setup lang="ts">
interface Props {
  text?: string
}

defineProps<Props>()
</script>

<template>
  <h2 class="text-black dark:text-white text-2xl font-semibold">
    <span v-if="text">{{ text }}</span>
    <slot v-else />
  </h2>
</template>