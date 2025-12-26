<script lang="ts">
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { backendClient } from '$lib/backendClient';
  import type { Section, Course } from '$lib/backendClient';
  import CourseHeader from '$lib/components/CourseHeader.svelte';
  import CourseFilters from '$lib/components/CourseFilters.svelte';
  import SectionList from '$lib/components/SectionList.svelte';
  import { ArrowLeft } from 'lucide-svelte';

  let courseId = $derived(parseInt($page.params.id));
  let token = $state<string | null>(null);
  
  let course = $state<Course | null>(null);
  let sections = $state<Section[]>([]);
  let isLoading = $state(true);
  let error = $state<string | null>(null);

  // Filter State
  let visibleSections = $state<Set<string>>(new Set());
  let availableActivityTypes = $state<string[]>([]);
  let visibleActivityTypes = $state<Set<string>>(new Set(['book'])); // Default to 'book'
  let searchQuery = $state('');
  
  // Sync State
  let isSyncing = $state(false);
  let syncStatus = $state<'idle' | 'syncing' | 'success' | 'error'>('idle');
  let totalActivities = $state(0);
  let abortController = $state<AbortController | null>(null);

  // Cache State
  let clearCacheStatus = $state<'idle' | 'clearing' | 'success' | 'error'>('idle');

  onMount(async () => {
    token = localStorage.getItem('moodle_token');
    if (!token) {
      goto('/');
      return;
    }

    await loadCourseData();
  });

  async function loadCourseData() {
    if (!token) return;
    isLoading = true;
    error = null;

    try {
      // 1. Fetch Course Info (to get name)
      // Ideally we cache this or pass it, but fetching list is fast enough typically or we can improve later.
      const coursesResponse = await backendClient.getCourses(token);
      const foundCourse = coursesResponse.courses.find(c => c.id === courseId);
      
      if (foundCourse) {
        course = foundCourse;
      }

      // 2. Fetch Sections
      const contentsResponse = await backendClient.getCourseContents(token, courseId);
      sections = contentsResponse.sections;

      // Initialize Filters
      const allSectionNames = new Set(sections.map(s => s.name));
      visibleSections = allSectionNames;

      const types = new Set<string>();
      sections.forEach(section => {
        section.activities.forEach(activity => {
             types.add(activity.modname);
        });
      });
      availableActivityTypes = Array.from(types);

    } catch (e: any) {
      console.error('Failed to load course', e);
      error = e.message || 'Failed to load course content';
    } finally {
      isLoading = false;
    }
  }

  function handleToggleSectionVisibility(sectionName: string) {
    const newSet = new Set(visibleSections);
    if (newSet.has(sectionName)) {
      newSet.delete(sectionName);
    } else {
      newSet.add(sectionName);
    }
    visibleSections = newSet;
  }

  function handleToggleAllSections() {
    if (visibleSections.size === sections.length) {
      visibleSections = new Set();
    } else {
      visibleSections = new Set(sections.map(s => s.name));
    }
  }

  function handleToggleActivityType(type: string) {
    const newSet = new Set(visibleActivityTypes);
    if (newSet.has(type)) {
      newSet.delete(type);
    } else {
      newSet.add(type);
    }
    visibleActivityTypes = newSet;
  }

  function handleToggleAllActivityTypes() {
    // If all available are selected, reset to default 'book'
    // Or if currently only 'book' is selected (default), select all?
    // Let's implement: If size equals available size, reset to 'book'. Else select all.
    if (visibleActivityTypes.size === availableActivityTypes.length) {
        visibleActivityTypes = new Set(['book']); // Reset to default
    } else {
        visibleActivityTypes = new Set(availableActivityTypes);
    }
  }

  // --- Sync Logic ---
  async function handleSync() {
    if (!token || isSyncing) return;
    
    isSyncing = true;
    syncStatus = 'syncing';
    abortController = new AbortController();

    // 1. Collect all URLs to sync
    const urlsToSync: string[] = [];
    sections.forEach(section => {
        if (!visibleSections.has(section.name)) return;
        section.activities.forEach(activity => {
            if (!visibleActivityTypes.has(activity.modname)) return;
            urlsToSync.push(activity.url);
        });
    });

    totalActivities = urlsToSync.length;

    try {
       // Using batchPrefetch from backendClient
       // Note: backendClient.batchPrefetch takes urls array.
       const result = await backendClient.batchPrefetch(token, urlsToSync);
       
       if (result.success) {
           syncStatus = 'success';
           // Revert status after 2 seconds
           setTimeout(() => syncStatus = 'idle', 2000);
       } else {
           syncStatus = 'error';
       }

    } catch (e) {
        if ((e as Error).name === 'AbortError') {
            console.log('Sync cancelled');
            syncStatus = 'idle';
        } else {
            console.error('Sync failed', e);
            syncStatus = 'error';
        }
    } finally {
        isSyncing = false;
        abortController = null;
    }
  }

  function handleCancelSync() {
    if (abortController) {
        abortController.abort();
    }
  }

  async function handleClearCache() {
      clearCacheStatus = 'clearing';
      try {
          await backendClient.clearCache();
          clearCacheStatus = 'success';
          setTimeout(() => clearCacheStatus = 'idle', 2000);
          
          // Reload data
          await loadCourseData(); 
      } catch (e) {
          console.error(e);
          clearCacheStatus = 'error';
      }
  }

  // Filter Logic
  const filteredSections = $derived(sections
    .filter(section => visibleSections.has(section.name))
    .map(section => ({
      ...section,
      activities: section.activities.filter(activity => {
        // Type filter
        if (!visibleActivityTypes.has(activity.modname)) return false;
        
        // Search filter
        if (searchQuery) {
            return activity.name.toLowerCase().includes(searchQuery.toLowerCase());
        }
        
        return true;
      })
    }))
    .filter(section => section.activities.length > 0) // Hide empty sections
  );

</script>

{#if isLoading}
  <div class="min-h-screen flex items-center justify-center bg-black">
    <div class="h-8 w-8 border-2 border-primary border-t-white rounded-full animate-spin"></div>
  </div>
{:else if error}
  <div class="min-h-screen flex items-center justify-center bg-black text-red-500">
    <div class="text-center">
        <p class="text-xl font-bold mb-2">Error</p>
        <p>{error}</p>
        <button onclick={() => goto('/dashboard')} class="mt-4 text-white underline">Back to Dashboard</button>
    </div>
  </div>
{:else}
  <div class="min-h-screen bg-black">
    <!-- Header -->
    <header class="sticky top-0 z-40 bg-black/50 backdrop-blur-xl border-b border-neutral-800">
      <div class="container mx-auto px-4 py-4">
        <div class="flex items-center gap-4 mb-4">
          <a href="/dashboard" class="p-2 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors">
            <ArrowLeft size={20} />
          </a>
          {#if course}
            <CourseHeader 
              courseName={course.fullname} 
              totalSections={sections.length} 
              visibleSections={filteredSections.length}
            />
          {/if}
        </div>
        
        <CourseFilters
            {sections}
            {visibleSections}
            onToggleSectionVisibility={handleToggleSectionVisibility}
            onToggleAllSections={handleToggleAllSections}
            
            {availableActivityTypes}
            {visibleActivityTypes}
            onToggleActivityType={handleToggleActivityType}
            onToggleAllActivityTypes={handleToggleAllActivityTypes}
            
            {searchQuery}
            onSearchChange={(q) => searchQuery = q}
            
            {isSyncing}
            {syncStatus}
            onSync={handleSync}
            onCancelSync={handleCancelSync}
            {totalActivities}
            
            {clearCacheStatus}
            onClearCache={handleClearCache}
        />
      </div>
    </header>

    <!-- Content -->
    <main class="container mx-auto px-4 py-8 pb-32">
       <SectionList sections={filteredSections} />
    </main>
  </div>
{/if}
