<script setup lang="ts">
interface Props {
  text?: string
}

defineProps<Props>()
</script>

<template>
  <h1 class="text-black dark:text-white text-5xl font-bold">
    <span v-if="text">{{ text }}</span>
    <slot v-else />
  </h1>
</template>