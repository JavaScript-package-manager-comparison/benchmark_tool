<script setup lang="ts">
import type { ButtonProps } from '@nuxt/ui'

interface Props {
  icon: ButtonProps['icon']
  label?: ButtonProps['label']
  variant: ButtonProps['variant']
}

const props = defineProps<Props>()
</script>

<template>
  <UButton
      :label="props.label"
      :variant="props.variant"
      :icon="props.icon"
      class="cursor-pointer"
  />
</template>