<script lang="ts">
  import { Settings, Check, Search } from 'lucide-svelte';

  interface Course {
    id: number;
    fullname: string;
    shortname: string;
  }

  interface Props {
    allCourses: Course[];
    initialSelectedIds: number[];
    onSelectionChange?: (selectedIds: number[]) => void;
  }

  let { allCourses, initialSelectedIds, onSelectionChange }: Props = $props();

  let isOpen = $state(false);
  
  // Filter initial IDs
  const validInitialIds = initialSelectedIds.filter(id => allCourses.some(c => c.id === id));
  
  let selectedIds = $state(new Set(validInitialIds));
  
  $effect(() => {
    if (isOpen) {
      selectedIds = new Set(validInitialIds);
    }
  });
  let searchQuery = $state('');

  function toggleCourse(id: number) {
    const newSelected = new Set(selectedIds);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    selectedIds = newSelected;
  }

  function selectAll() {
    selectedIds = new Set(allCourses.map(c => c.id));
  }

  function deselectAll() {
    selectedIds = new Set();
  }

  function handleSave() {
    const selected = Array.from(selectedIds);
    localStorage.setItem('selected_courses', JSON.stringify(selected));
    isOpen = false;
    
    if (onSelectionChange) {
      onSelectionChange(selected);
    } else {
      window.location.reload();
    }
  }

  const displayedCourses = $derived(allCourses.filter(course => 
    course.fullname.toLowerCase().includes(searchQuery.toLowerCase()) || 
    course.shortname.toLowerCase().includes(searchQuery.toLowerCase())
  ));
</script>

<button
  onclick={() => isOpen = true}
  class="flex items-center gap-2 px-4 py-2 bg-neutral-900 border border-neutral-800 rounded-lg hover:border-neutral-600 transition-colors text-sm"
>
  <Settings size={16} />
  Manage Courses
</button>

{#if isOpen}
  <div class="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4">
    <div class="bg-neutral-900 border border-neutral-800 rounded-xl max-w-2xl w-full max-h-[80vh] flex flex-col">
      <!-- Header -->
      <div class="p-6 border-b border-neutral-800">
        <h2 class="text-xl font-bold text-white">Select Courses to Display</h2>
        <p class="text-sm text-neutral-500 mt-1">
          Choose which courses appear on your dashboard
        </p>
      </div>

      <!-- Search & List -->
      <div class="flex-1 overflow-hidden flex flex-col">
        <div class="px-6 py-3 border-b border-neutral-800">
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-neutral-500">
              <Search size={16} />
            </div>
            <input
              type="text"
              value={searchQuery}
              oninput={(e) => searchQuery = e.currentTarget.value}
              placeholder="Filter courses..."
              class="w-full bg-black border border-neutral-800 text-white text-sm rounded-lg pl-9 pr-4 py-2 focus:ring-1 focus:ring-neutral-700 focus:border-neutral-700 placeholder-neutral-600 transition-all"
            />
          </div>
        </div>

        <div class="flex-1 overflow-y-auto p-6">
          <div class="space-y-2">
            {#each displayedCourses as course (course.id)}
              <div
                class="flex items-center gap-3 p-3 rounded-lg hover:bg-neutral-800/50 cursor-pointer transition-colors"
                role="checkbox"
                aria-checked={selectedIds.has(course.id)}
                tabindex="0"
                onkeypress={(e) => { if (e.key === 'Enter' || e.key === ' ') toggleCourse(course.id); }}
                onclick={() => toggleCourse(course.id)}
              >
                <div class="relative">
                  <div class={`w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                    selectedIds.has(course.id) 
                      ? 'bg-white border-white' 
                      : 'border-neutral-600 bg-transparent'
                  }`}>
                    {#if selectedIds.has(course.id)}
                      <Check size={14} class="text-black" />
                    {/if}
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-white font-medium truncate">{course.fullname}</div>
                  <div class="text-xs text-neutral-500 font-mono">{course.shortname}</div>
                </div>
              </div>
            {/each}
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="p-6 border-t border-neutral-800 flex items-center justify-between">
        <div class="flex gap-2">
          <button
            onclick={selectAll}
            class="text-sm text-neutral-400 hover:text-white transition-colors"
          >
            Select All
          </button>
          <span class="text-neutral-700">|</span>
          <button
            onclick={deselectAll}
            class="text-sm text-neutral-400 hover:text-white transition-colors"
          >
            Deselect All
          </button>
        </div>

        <div class="flex gap-3">
          <button
            onclick={() => isOpen = false}
            class="px-4 py-2 text-neutral-400 hover:text-white transition-colors"
          >
            Cancel
          </button>
          <button
            onclick={handleSave}
            disabled={selectedIds.size === 0}
            class="px-4 py-2 bg-white text-black rounded-lg font-medium hover:bg-neutral-200 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Save ({selectedIds.size})
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
