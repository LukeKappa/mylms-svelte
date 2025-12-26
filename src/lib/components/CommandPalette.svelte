<script lang="ts">
  import { BookOpen, ArrowRight } from "lucide-svelte";
  import { goto } from "$app/navigation";
  import SearchDialog from "$lib/components/ui/SearchDialog.svelte";
  import SearchTrigger from "$lib/components/ui/SearchTrigger.svelte";

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
  let query = $state("");
  let selectedIndex = $state(0);
  let resultsListRef = $state<HTMLDivElement | null>(null);

  const filteredCourses = $derived(
    allCourses
      .filter(
        (course) =>
          course.fullname.toLowerCase().includes(query.toLowerCase()) ||
          course.shortname.toLowerCase().includes(query.toLowerCase()),
      )
      .slice(0, 5),
  );

  function handleKeyDown(e: KeyboardEvent) {
    if ((e.ctrlKey || e.metaKey) && e.key === "k") {
      e.preventDefault();
      isOpen = !isOpen;
    }

    if (!isOpen) return;

    if (e.key === "ArrowDown") {
      e.preventDefault();
      selectedIndex = (selectedIndex + 1) % (filteredCourses.length || 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      selectedIndex =
        (selectedIndex - 1 + (filteredCourses.length || 1)) %
        (filteredCourses.length || 1);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (filteredCourses[selectedIndex]) {
        handleSelect(filteredCourses[selectedIndex].id);
      }
    }
  }

  function handleSelect(courseId: number) {
    goto(`/dashboard/course/${courseId}`);
    isOpen = false;
    query = "";
    selectedIndex = 0;
  }

  $effect(() => {
    if (typeof window !== "undefined") {
      window.addEventListener("keydown", handleKeyDown);
      return () => window.removeEventListener("keydown", handleKeyDown);
    }
  });

  // Reset selection on query change
  $effect(() => {
    if (query || !query) selectedIndex = 0;
  });
</script>

<SearchTrigger onClick={() => (isOpen = true)} label="Search courses..." />

<SearchDialog
  {isOpen}
  bind:query
  onClose={() => (isOpen = false)}
  placeholder="Search courses..."
  footerResultsCount={filteredCourses.length}
>
  <!-- Results Slot -->
  {#if filteredCourses.length === 0}
    <div class="p-8 text-center text-neutral-500 text-sm">
      {query ? "No results found." : "Type to search..."}
    </div>
  {:else}
    <div class="flex flex-col gap-1" bind:this={resultsListRef}>
      <div
        class="px-2 py-1.5 text-xs font-semibold text-neutral-500 uppercase tracking-wider"
      >
        Courses
      </div>
      {#each filteredCourses as course, index (course.id)}
        <button
          onclick={() => handleSelect(course.id)}
          onmouseenter={() => (selectedIndex = index)}
          class={`w-full flex items-center justify-between px-3 py-3 rounded-lg transition-colors group text-left ${
            index === selectedIndex
              ? "bg-blue-600/10 text-white"
              : "text-neutral-400 hover:bg-neutral-800 hover:text-neutral-200"
          }`}
        >
          <div class="flex items-center gap-3 min-w-0">
            <div
              class={`p-2 rounded-md ${
                index === selectedIndex
                  ? "bg-blue-600/20 text-blue-400"
                  : "bg-neutral-800 border border-neutral-700 text-neutral-500"
              }`}
            >
              <BookOpen size={16} />
            </div>
            <div class="min-w-0">
              <div class="font-medium truncate">{course.fullname}</div>
              <div class="text-xs text-neutral-500 font-mono truncate">
                {course.shortname}
              </div>
            </div>
          </div>
          {#if index === selectedIndex}
            <div class="flex items-center gap-2 text-blue-400">
              <span class="text-xs">Open</span>
              <ArrowRight size={14} />
            </div>
          {/if}
        </button>
      {/each}
    </div>
  {/if}
</SearchDialog>
