<script lang="ts">
  import type { Section } from '$lib/backendClient';
  import ActivityItem from './ActivityItem.svelte';

  interface Props {
    sections: Section[];
  }

  let { sections }: Props = $props();
</script>

{#if sections.length === 0}
  <div class="text-center py-12 bg-neutral-900/30 rounded-xl border border-neutral-800 border-dashed">
    <p class="text-neutral-500">No sections selected. Use the filter to view content.</p>
  </div>
{:else}
  <div class="space-y-8">
    {#each sections as section (section.id)}
      <div class="bg-neutral-900/50 border border-neutral-800 rounded-xl overflow-hidden">
        <div class="px-6 py-4 border-b border-neutral-800 bg-neutral-900">
          <h2 class="text-lg font-semibold text-white">{section.name}</h2>
        </div>
        
        <div class="divide-y divide-neutral-800">
          {#each section.activities as activity, idx (`${section.id}-${idx}`)}
            <ActivityItem {activity} />
          {/each}
        </div>
      </div>
    {/each}
  </div>
{/if}
