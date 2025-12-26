<script lang="ts">
  interface Props {
    courseName: string;
    totalSections: number;
    visibleSections: number;
  }

  let { courseName, totalSections, visibleSections }: Props = $props();
</script>

<div>
  <h1 class="text-2xl font-bold text-white mb-2">{courseName}</h1>
  <p class="text-neutral-400 text-sm">
    Showing {visibleSections} of {totalSections} sections
  </p>
</div>
