<script lang="ts">
  import { BookOpen, CheckCircle2 } from 'lucide-svelte';
  import CourseSelection from './CourseSelection.svelte';
  import type { Course } from '$lib/backendClient';

  interface Props {
    allCourses: Course[];
    selectedIds: number[];
    onSelectionChange?: (selectedIds: number[]) => void;
  }

  let { allCourses, selectedIds, onSelectionChange }: Props = $props();

  const displayCourses = $derived(selectedIds.length > 0 
    ? allCourses.filter(c => selectedIds.includes(c.id))
    : allCourses);
</script>

<div>
  <!-- Header Section -->
  <div class="mb-8 flex flex-col md:flex-row md:items-end justify-between gap-4">
    <div>
      <h1 class="text-2xl font-bold text-white">My Courses</h1>
      <p class="text-neutral-500">
        {#if selectedIds.length > 0}
          Showing {displayCourses.length} of {allCourses.length} courses
        {:else}
          You are enrolled in {allCourses.length} courses
        {/if}
      </p>
    </div>
    
    <div class="flex items-center gap-3 w-full md:w-auto justify-end">
      <CourseSelection 
        allCourses={allCourses.map(c => ({ 
          id: c.id, 
          fullname: c.fullname, 
          shortname: c.shortname 
        }))}
        initialSelectedIds={selectedIds}
        {onSelectionChange}
      />
    </div>
  </div>

  <!-- Course Grid -->
  {#if displayCourses.length === 0}
    <div class="text-center py-16 border border-dashed border-neutral-800 rounded-xl">
      <p class="text-neutral-500 text-lg">No courses found</p>
      <p class="text-neutral-600 text-sm mt-2">
        Click "Manage Courses" to select courses to display
      </p>
    </div>
  {:else}
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
      {#each displayCourses as course (course.id)}
        <a 
          href={`/dashboard/course/${course.id}`}
          class="block"
        >
          <div 
            class="bg-neutral-900/50 border border-neutral-800 rounded-xl p-4 hover:border-neutral-600 transition-all group shadow-sm hover:shadow-md cursor-pointer h-full flex flex-col"
          >
            <div class="flex items-start justify-between mb-3">
              <div class="p-2 bg-neutral-800 rounded-lg text-neutral-400 group-hover:bg-white group-hover:text-black transition-colors">
                <BookOpen size={20} />
              </div>
            </div>
            
            <h3 class="font-semibold text-lg text-white mb-1 line-clamp-2" title={course.fullname}>
              {course.fullname}
            </h3>
            
            <p class="text-neutral-500 font-mono text-sm mb-4 line-clamp-1">
              {course.shortname}
            </p>
            
            {#if course.progress !== undefined && course.progress !== null}
              <div class="mt-auto">
                <div class="flex justify-between text-xs text-neutral-500 mb-1">
                  <span>Progress</span>
                  <span>{Math.round(course.progress)}%</span>
                </div>
                <div class="h-2 bg-neutral-800 rounded-full overflow-hidden">
                  <div 
                    class="h-full bg-white rounded-full" 
                    style="width: {course.progress}%"
                  ></div>
                </div>
              </div>
            {/if}
          </div>
        </a>
      {/each}
    </div>
  {/if}
</div>
