<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  
  let { children } = $props();
</script>

<svelte:head>
  <title>MyLocalMS</title>
  <meta name="description" content="A high-performance, offline-first Moodle dashboard" />
</svelte:head>

<div class="min-h-screen bg-black text-neutral-200">
  {@render children()}
</div>
