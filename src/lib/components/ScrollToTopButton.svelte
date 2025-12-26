<script lang="ts">
  import { ArrowUp } from 'lucide-svelte';

  let isVisible = $state(false);

  function toggleVisibility() {
    if (window.scrollY > 300) {
      isVisible = true;
    } else {
      isVisible = false;
    }
  }

  function scrollToTop() {
    const tocElement = document.getElementById('table-of-contents');
    if (tocElement) {
      tocElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
    } else {
      const contentElement = document.querySelector('.activity-content');
      if (contentElement) {
        contentElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } else {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    }
  }

  $effect(() => {
    window.addEventListener('scroll', toggleVisibility);
    return () => window.removeEventListener('scroll', toggleVisibility);
  });
</script>

{#if isVisible}
  <div class="fixed bottom-8 left-1/2 transform -translate-x-1/2 z-50">
    <button
      onclick={scrollToTop}
      class="bg-neutral-900/90 hover:bg-neutral-800 text-neutral-300 border border-neutral-700 hover:border-neutral-600 p-3 rounded-full shadow-lg backdrop-blur-sm transition-all duration-300 flex items-center gap-2 group"
      aria-label="Scroll to top"
    >
      <ArrowUp size={20} class="group-hover:-translate-y-1 transition-transform text-white" />
      <span class="text-sm font-medium pr-1">Back to Top</span>
    </button>
  </div>
{/if}
