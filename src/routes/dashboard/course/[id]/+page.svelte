<script lang="ts">
  import { onMount } from "svelte";
  import { page } from "$app/stores";
  import { goto } from "$app/navigation";
  import { backendClient } from "$lib/backendClient";
  import type { Section, Course } from "$lib/backendClient";
  import CourseHeader from "$lib/components/CourseHeader.svelte";
  import CourseFilters from "$lib/components/CourseFilters.svelte";
  import SectionList from "$lib/components/SectionList.svelte";
  import CourseSearchPalette from "$lib/components/CourseSearchPalette.svelte";
  import { ArrowLeft } from "lucide-svelte";
  import { dbService } from "$lib/indexedDB";

  let courseId = $derived(parseInt($page.params.id));
  let token = $state<string | null>(null);

  let course = $state<Course | null>(null);
  let allCourses = $state<Course[]>([]);
  let sections = $state<Section[]>([]);
  let isLoading = $state(true);
  let error = $state<string | null>(null);

  // Filter State
  let visibleSections = $state<Set<string>>(new Set());
  let availableActivityTypes = $state<string[]>([]);
  let visibleActivityTypes = $state<Set<string>>(new Set(["book"])); // Default to 'book'
  let searchQuery = $state("");

  // Sync State
  let isSyncing = $state(false);
  let syncStatus = $state<"idle" | "syncing" | "success" | "error">("idle");
  let totalActivities = $state(0);
  let abortController = $state<AbortController | null>(null);

  // Cache State
  let clearCacheStatus = $state<"idle" | "clearing" | "success" | "error">(
    "idle",
  );

  // Search Index State
  interface SearchIndexItem {
    text: string;
    type: "heading" | "activity";
    activityId: string;
    activityName: string;
    sectionName: string;
    modname: string;
    anchorId?: string;
  }

  let searchIndex = $state<SearchIndexItem[]>([]);

  onMount(async () => {
    token = localStorage.getItem("moodle_token");
    if (!token) {
      goto("/");
      return;
    }

    await loadCourseData();
  });

  // Helper for consistent IDs
  function getUniqueIdFromUrl(url: string): string {
    let hash = 0;
    for (let i = 0; i < url.length; i++) {
      const char = url.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

  async function prefetchAllContent() {
    if (!token || !sections.length) return;

    console.log("[Prefetch] Starting batch prefetch...");
    const allActivities: { activity: any; sectionName: string }[] = [];
    const urls: string[] = [];

    sections.forEach((section) => {
      // Ensure section.activities exists before iterating
      if (section.activities) {
        section.activities.forEach((activity) => {
          // Broad prefetch for commonly used text types
          if (["book", "page", "resource"].includes(activity.modname)) {
            allActivities.push({ activity, sectionName: section.name });
            urls.push(activity.url);
          }
        });
      }
    });

    if (urls.length === 0) return;

    // 1. Load from Cache & Build Index immediately if possible
    const tempIndex: SearchIndexItem[] = [];

    // Helper to process content
    const processContent = (
      content: string,
      activity: any,
      sectionName: string,
    ) => {
      const uniquePrefix = getUniqueIdFromUrl(activity.url);
      if (typeof document === "undefined") return;

      const parser = new DOMParser();
      const doc = parser.parseFromString(content, "text/html");
      const headings = doc.querySelectorAll("h1, h2, h3"); // H1-H3 mainly

      let count = 0;
      headings.forEach((heading) => {
        const text = heading.textContent?.trim();
        if (text && text.length < 100) {
          // Logic matching ActivityItem sequential ID generation
          let id = `heading-${uniquePrefix}-${count}`;
          const existingId = heading.getAttribute("id");
          if (existingId) {
            id = `${uniquePrefix}-${existingId}`;
          }
          count++;

          tempIndex.push({
            text,
            type: "heading",
            activityId: activity.id,
            activityName: activity.name,
            sectionName,
            modname: activity.modname,
            anchorId: id,
          });
        }
      });
    };

    // Check DB first (Fast Path)
    for (const item of allActivities) {
      const cached = await dbService.getActivity(item.activity.url);
      if (cached) {
        processContent(cached, item.activity, item.sectionName);
      }
    }
    if (tempIndex.length > 0) {
      searchIndex = [...tempIndex];
    }

    // 2. Network Fetch (Background)
    try {
      const result = await backendClient.batchPrefetch(token, urls);
      if (result.success && result.items) {
        const freshIndex: SearchIndexItem[] = [];
        const urlMap = new Map(allActivities.map((x) => [x.activity.url, x]));

        for (const item of result.items) {
          if (item.success && item.content) {
            await dbService.saveActivity(item.url, item.content);

            const info = urlMap.get(item.url);
            if (info) {
              const uniquePrefix = getUniqueIdFromUrl(info.activity.url);
              if (typeof document !== "undefined") {
                const parser = new DOMParser();
                const doc = parser.parseFromString(item.content, "text/html");
                const headings = doc.querySelectorAll("h1, h2, h3");
                let count = 0;
                headings.forEach((heading) => {
                  const text = heading.textContent?.trim();
                  if (text && text.length < 100) {
                    let id = `heading-${uniquePrefix}-${count}`;
                    const existingId = heading.getAttribute("id");
                    if (existingId) {
                      id = `${uniquePrefix}-${existingId}`;
                    }
                    count++;
                    freshIndex.push({
                      text,
                      type: "heading",
                      activityId: info.activity.id,
                      activityName: info.activity.name,
                      sectionName: info.sectionName,
                      modname: info.activity.modname,
                      anchorId: id,
                    });
                  }
                });
              }
            }
          }
        }

        // Update index if we got fresh results
        if (freshIndex.length > 0) {
          // We might want to merge or just replace?
          // Replacing is safer to avoid stale duplicates.
          searchIndex = freshIndex;
          console.log(
            `[Indexer] Rebuilt index with ${freshIndex.length} items`,
          );
        }
      }
    } catch (e) {
      console.error("Batch prefetch failed", e);
    }
  }

  async function loadCourseData() {
    if (!token) return;
    isLoading = true;
    error = null;

    try {
      // 1. Fetch Course Info
      const coursesResponse = await backendClient.getCourses(token);
      allCourses = coursesResponse.courses;
      const foundCourse = coursesResponse.courses.find(
        (c) => c.id === courseId,
      );

      if (foundCourse) {
        course = foundCourse;
      }

      // 2. Fetch Sections
      const contentsResponse = await backendClient.getCourseContents(
        token,
        courseId,
      );
      sections = contentsResponse.sections;

      // 3. Trigger Eager Load (Fire and forget)
      prefetchAllContent();

      // Initialize Filters
      const allSectionNames = new Set(sections.map((s) => s.name));
      visibleSections = allSectionNames;

      const types = new Set<string>();
      sections.forEach((section) => {
        if (section.activities) {
          section.activities.forEach((activity) => {
            types.add(activity.modname);
          });
        }
      });
      availableActivityTypes = Array.from(types);
    } catch (e: any) {
      console.error("Failed to load course", e);
      error = e.message || "Failed to load course content";
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
      visibleSections = new Set(sections.map((s) => s.name));
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
    if (visibleActivityTypes.size === availableActivityTypes.length) {
      visibleActivityTypes = new Set(["book"]); // Reset to default
    } else {
      visibleActivityTypes = new Set(availableActivityTypes);
    }
  }

  // --- Sync Logic ---
  async function handleSync() {
    if (!token || isSyncing) return;

    isSyncing = true;
    syncStatus = "syncing";
    abortController = new AbortController();

    // 1. Collect all URLs to sync
    const urlsToSync: string[] = [];
    sections.forEach((section) => {
      if (!visibleSections.has(section.name)) return;
      if (section.activities) {
        section.activities.forEach((activity) => {
          if (!visibleActivityTypes.has(activity.modname)) return;
          urlsToSync.push(activity.url);
        });
      }
    });

    totalActivities = urlsToSync.length;

    try {
      const result = await backendClient.batchPrefetch(token, urlsToSync);

      if (result.success) {
        syncStatus = "success";
        setTimeout(() => (syncStatus = "idle"), 2000);
      } else {
        syncStatus = "error";
      }
    } catch (e) {
      if ((e as Error).name === "AbortError") {
        console.log("Sync cancelled");
        syncStatus = "idle";
      } else {
        console.error("Sync failed", e);
        syncStatus = "error";
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
    clearCacheStatus = "clearing";
    try {
      await backendClient.clearCache();
      clearCacheStatus = "success";
      setTimeout(() => (clearCacheStatus = "idle"), 2000);

      await loadCourseData();
    } catch (e) {
      console.error(e);
      clearCacheStatus = "error";
    }
  }

  // Filter Logic
  const filteredSections = $derived(
    sections
      .filter((section) => visibleSections.has(section.name))
      .map((section) => ({
        ...section,
        activities: (section.activities || []).filter((activity) => {
          // Type filter
          if (!visibleActivityTypes.has(activity.modname)) return false;

          // Search filter
          if (searchQuery) {
            return activity.name
              .toLowerCase()
              .includes(searchQuery.toLowerCase());
          }

          return true;
        }),
      }))
      .filter((section) => section.activities.length > 0), // Hide empty sections
  );
</script>

{#if isLoading}
  <div class="min-h-screen flex items-center justify-center bg-black">
    <div
      class="h-8 w-8 border-2 border-primary border-t-white rounded-full animate-spin"
    ></div>
  </div>
{:else if error}
  <div
    class="min-h-screen flex items-center justify-center bg-black text-red-500"
  >
    <div class="text-center">
      <p class="text-xl font-bold mb-2">Error</p>
      <p>{error}</p>
      <button
        onclick={() => goto("/dashboard")}
        class="mt-4 text-white underline">Back to Dashboard</button
      >
    </div>
  </div>
{:else}
  <div class="min-h-screen bg-black">
    <!-- Header -->
    <header
      class="sticky top-0 z-40 bg-black/50 backdrop-blur-xl border-b border-neutral-800"
    >
      <div class="container mx-auto px-4 py-4">
        <div
          class="flex flex-col md:flex-row md:items-center justify-between gap-4"
        >
          <div class="flex items-center gap-4">
            <a
              href="/dashboard"
              class="p-2 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors"
            >
              <ArrowLeft size={20} />
            </a>
            {#if course}
              <CourseHeader
                courseName={course.fullname}
                totalSections={sections.length}
                visibleSections={filteredSections.length}
              />
            {/if}
            <div class="hidden md:block w-px h-6 bg-neutral-800 mx-2"></div>
            <CourseSearchPalette {sections} {searchIndex} />
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
            onSearchChange={(q) => (searchQuery = q)}
            {isSyncing}
            {syncStatus}
            onSync={handleSync}
            onCancelSync={handleCancelSync}
            {totalActivities}
            {clearCacheStatus}
            onClearCache={handleClearCache}
          />
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="container mx-auto px-4 py-8 pb-32">
      <SectionList sections={filteredSections} />
    </main>
  </div>
{/if}
