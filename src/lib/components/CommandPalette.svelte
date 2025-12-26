<script lang="ts">
  import { Search, BookOpen, X, ArrowRight } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  
  interface Course {
    id: number;
    fullname: string;
    shortname: string;
  }

  interface Props {
    allCourses: Course[];
  }

  let { allCourses }: Props = $props();

  let isOpen = $state(false);
  let query = $state('');
  let selectedIndex = $state(0);
  let inputRef: HTMLInputElement | null = null;
  
  const filteredCourses = $derived(allCourses.filter(course => 
    course.fullname.toLowerCase().includes(query.toLowerCase()) || 
    course.shortname.toLowerCase().includes(query.toLowerCase())
  ).slice(0, 5));

  function handleKeyDown(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      isOpen = !isOpen;
    }

    if (!isOpen) return;

    if (e.key === 'Escape') {
      isOpen = false;
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      selectedIndex = (selectedIndex + 1) % filteredCourses.length;
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      selectedIndex = (selectedIndex - 1 + filteredCourses.length) % filteredCourses.length;
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (filteredCourses[selectedIndex]) {
        goto(`/dashboard/course/${filteredCourses[selectedIndex].id}`);
        isOpen = false;
      }
    }
  }

  $effect(() => {
    if (typeof window !== 'undefined') {
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }
  });

  $effect(() => {
    if (isOpen && inputRef) {
      inputRef.focus();
    }
    if (!isOpen) {
      query = '';
      selectedIndex = 0;
    }
  });
</script>

<!-- Trigger Button (Visible in Header) -->
<button
  onclick={() => isOpen = true}
  class="hidden md:flex items-center gap-2 px-3 py-1.5 bg-neutral-900 border border-neutral-800 rounded-md text-neutral-500 hover:text-neutral-300 hover:border-neutral-700 transition-all text-sm group"
>
  <Search size={14} />
  <span>Search...</span>
  <kbd class="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-mono bg-neutral-800 rounded border border-neutral-700 text-neutral-400 group-hover:text-neutral-300">
    Ctrl K
  </kbd>
</button>

<!-- Mobile Trigger (Icon Only) -->
<button
  onclick={() => isOpen = true}
  class="md:hidden p-2 text-neutral-400 hover:text-white"
>
  <Search size={20} />
</button>

<!-- Modal -->
{#if isOpen}
  <div class="fixed inset-0 z-50 flex items-start justify-center pt-[20vh] px-4">
    <!-- Backdrop -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="absolute inset-0 bg-black/60 backdrop-blur-sm"
      onclick={() => isOpen = false}
    ></div>

    <!-- Dialog -->
    <div class="relative w-full max-w-xl bg-black border border-neutral-800 rounded-xl shadow-2xl overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-100">
      <!-- Search Input -->
      <div class="flex items-center px-4 py-3 border-b border-neutral-800">
        <Search size={20} class="text-neutral-500 mr-3" />
        <input
          bind:this={inputRef}
          type="text"
          value={query}
          oninput={(e) => {
            query = e.currentTarget.value;
            selectedIndex = 0;
          }}
          placeholder="Search courses..."
          class="flex-1 bg-transparent border-none outline-none text-white placeholder-neutral-600 text-lg"
        />
        <button 
          onclick={() => isOpen = false}
          class="p-1 text-neutral-500 hover:text-white rounded-md"
        >
          <X size={18} />
        </button>
      </div>

      <!-- Results -->
      <div class="max-h-[60vh] overflow-y-auto p-2">
        {#if filteredCourses.length === 0}
          <div class="p-8 text-center text-neutral-500">
            {query ? 'No results found.' : 'Type to search...'}
          </div>
        {:else}
          <div class="space-y-1">
            <div class="px-2 py-1.5 text-xs font-semibold text-neutral-500 uppercase tracking-wider">
              Courses
            </div>
            {#each filteredCourses as course, index (course.id)}
              <a
                href={`/dashboard/course/${course.id}`}
                onclick={() => isOpen = false}
                class={`flex items-center justify-between px-3 py-3 rounded-lg transition-colors group ${
                  index === selectedIndex 
                    ? 'bg-neutral-800 text-white' 
                    : 'text-neutral-400 hover:bg-neutral-900 hover:text-neutral-200'
                }`}
                onmouseenter={() => selectedIndex = index}
              >
                <div class="flex items-center gap-3 min-w-0">
                  <div class={`p-2 rounded-md ${
                    index === selectedIndex ? 'bg-neutral-700' : 'bg-neutral-900 border border-neutral-800'
                  }`}>
                    <BookOpen size={16} />
                  </div>
                  <div class="min-w-0">
                    <div class="font-medium truncate">{course.fullname}</div>
                    <div class="text-xs text-neutral-500 font-mono truncate">{course.shortname}</div>
                  </div>
                </div>
                {#if index === selectedIndex}
                  <ArrowRight size={16} class="text-neutral-500" />
                {/if}
              </a>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Footer -->
      <div class="px-4 py-2 bg-neutral-900/50 border-t border-neutral-800 text-[10px] text-neutral-500 flex justify-between items-center">
        <div class="flex gap-3">
          <span>Use <kbd class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700">↑</kbd> <kbd class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700">↓</kbd> to navigate</span>
          <span><kbd class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700">Enter</kbd> to select</span>
        </div>
        <span><kbd class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700">Esc</kbd> to close</span>
      </div>
    </div>
  </div>
{/if}
