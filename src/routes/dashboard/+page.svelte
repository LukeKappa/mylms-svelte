<script lang="ts">
  import { onMount } from "svelte";
  import { backendClient } from "$lib/backendClient";
  import type { Course } from "$lib/backendClient";
  import CourseList from "$lib/components/CourseList.svelte";
  import CommandPalette from "$lib/components/CommandPalette.svelte";

  import { LogOut, User as UserIcon } from "lucide-svelte";
  import { goto } from "$app/navigation";

  let courses = $state<Course[]>([]);
  let selectedCourseIds = $state<number[]>([]);
  let isLoading = $state(true);
  let user = $state<{ fullname: string; username: string } | null>(null);

  onMount(async () => {
    const token = localStorage.getItem("moodle_token");
    const storedUser = localStorage.getItem("moodle_user");

    if (!token) {
      goto("/");
      return;
    }

    if (storedUser) {
      try {
        user = JSON.parse(storedUser);
      } catch (e) {
        console.error("Failed to parse user", e);
      }
    }

    // Load selected courses preference
    try {
      const storedSelection = localStorage.getItem("selected_courses");
      if (storedSelection) {
        selectedCourseIds = JSON.parse(storedSelection);
      }
    } catch (e) {
      console.error("Failed to parse selected courses", e);
    }

    // Fetch courses
    try {
      // Fetch courses and user info
      if (token) {
        const response = await backendClient.getCourses(token);
        courses = response.courses;

        // Update user info from response
        user = {
          fullname: response.fullname,
          username: user?.username || "",
          // userid: response.userid
        };
        localStorage.setItem("moodle_user", JSON.stringify(user));

        if (selectedCourseIds.length === 0) {
          selectedCourseIds = response.courses.map((c) => c.id);
        }
      }
    } catch (e) {
      console.error("Failed to fetch dashboard data", e);
      if (
        (e as any).message?.includes("401") ||
        (e as any).message === "Invalid token"
      ) {
        localStorage.removeItem("moodle_token");
        goto("/");
      }
    } finally {
      isLoading = false;
    }
  });

  function handleLogout() {
    localStorage.removeItem("moodle_token");
    localStorage.removeItem("moodle_user");
    goto("/");
  }

  function handleSelectionChange(ids: number[]) {
    selectedCourseIds = ids;
    localStorage.setItem("selected_courses", JSON.stringify(ids));
  }
</script>

{#if isLoading}
  <div class="min-h-screen flex items-center justify-center bg-black">
    <div
      class="h-8 w-8 border-2 border-primary border-t-white rounded-full animate-spin"
    ></div>
  </div>
{:else}
  <div class="min-h-screen bg-black">
    <!-- Top Navigation Bar -->
    <header
      class="sticky top-0 z-40 w-full border-b border-neutral-800 bg-black/50 backdrop-blur-xl"
    >
      <div
        class="container mx-auto px-4 h-16 flex items-center justify-between"
      >
        <div class="flex items-center gap-4">
          <a
            href="/dashboard"
            class="text-xl font-bold text-white tracking-tight">MyLocalMS</a
          >
          <div class="hidden md:block w-px h-6 bg-neutral-800"></div>
          <CommandPalette
            allCourses={courses.map((c) => ({
              id: c.id,
              fullname: c.fullname,
              shortname: c.shortname,
            }))}
          />
        </div>

        <div class="flex items-center gap-4">
          <div class="w-px h-6 bg-neutral-800"></div>

          <div class="flex items-center gap-3">
            <div class="hidden md:block text-right">
              <p class="text-sm font-medium text-white">{user?.fullname}</p>
              <p class="text-xs text-neutral-500 font-mono">{user?.username}</p>
            </div>
            <div
              class="w-8 h-8 rounded-full bg-neutral-800 flex items-center justify-center border border-neutral-700"
            >
              <UserIcon size={14} class="text-neutral-400" />
            </div>

            <button
              onclick={handleLogout}
              class="ml-2 p-2 hover:bg-neutral-800 rounded-lg text-neutral-400 hover:text-white transition-colors"
              title="Logout"
            >
              <LogOut size={18} />
            </button>
          </div>
        </div>
      </div>
    </header>

    <!-- Main Content -->
    <main class="container mx-auto px-4 py-8">
      <CourseList
        allCourses={courses}
        selectedIds={selectedCourseIds}
        onSelectionChange={handleSelectionChange}
      />
    </main>
  </div>
{/if}
