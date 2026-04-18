<script setup lang="ts">
interface Props {
  text?: string
}

defineProps<Props>()
</script>

<template>
  <p class="text-black dark:text-white text-base leading-4">
    <span v-if="text">{{ text }}</span>
    <slot v-else />
  </p>
</template>