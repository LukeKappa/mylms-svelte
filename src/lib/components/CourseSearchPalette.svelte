<script lang="ts">
    import {
        FileText,
        ArrowRight,
        Folder,
        Link,
        Book,
        File,
        Hash,
        CornerDownLeft,
    } from "lucide-svelte";
    import SearchDialog from "$lib/components/ui/SearchDialog.svelte";
    import SearchTrigger from "$lib/components/ui/SearchTrigger.svelte";

    interface Activity {
        id: string;
        name: string;
        modname: string;
        url: string;
    }

    interface Section {
        id: number;
        name: string;
        activities: Activity[];
    }

    interface SearchIndexItem {
        text: string;
        type: "heading" | "activity";
        activityId: string;
        activityName: string;
        sectionName: string;
        modname: string;
        anchorId?: string;
    }

    interface Props {
        sections: Section[];
        searchIndex?: SearchIndexItem[];
    }

    let { sections, searchIndex = [] }: Props = $props();

    let isOpen = $state(false);
    let query = $state("");
    let selectedIndex = $state(0);
    let resultsListRef = $state<HTMLDivElement | null>(null);

    // Mixed results: Activities + Headings
    const searchResults = $derived.by(() => {
        if (!query) return [];
        const lowerQuery = query.toLowerCase();

        // 1. Activity Matches
        const activityMatches: SearchIndexItem[] = [];
        for (const section of sections) {
            if (!section.activities) continue;
            for (const activity of section.activities) {
                if (activity.name.toLowerCase().includes(lowerQuery)) {
                    activityMatches.push({
                        text: activity.name,
                        type: "activity",
                        activityId: activity.id,
                        activityName: activity.name,
                        sectionName: section.name,
                        modname: activity.modname,
                    });
                }
            }
        }

        // 2. Index Matches (Deep Search)
        const indexMatches: SearchIndexItem[] = [];
        for (const item of searchIndex) {
            if (item.text.toLowerCase().includes(lowerQuery)) {
                // Ensure modname present (from index) or fallback
                indexMatches.push({
                    ...item,
                    modname: (item as any).modname || "page",
                });
            }
        }

        // Combine (Activities first, then Topics)
        return [...activityMatches, ...indexMatches].slice(0, 20);
    });

    function handleKeyDown(e: KeyboardEvent) {
        if ((e.ctrlKey || e.metaKey) && e.key === "k") {
            e.preventDefault();
            isOpen = !isOpen;
        }

        if (!isOpen) return;

        if (e.key === "ArrowDown") {
            e.preventDefault();
            selectedIndex = (selectedIndex + 1) % (searchResults.length || 1);
            scrollToSelected();
        } else if (e.key === "ArrowUp") {
            e.preventDefault();
            selectedIndex =
                (selectedIndex - 1 + (searchResults.length || 1)) %
                (searchResults.length || 1);
            scrollToSelected();
        } else if (e.key === "Enter") {
            e.preventDefault();
            if (searchResults[selectedIndex]) {
                handleSelect(searchResults[selectedIndex]);
            }
        }
    }

    function scrollToSelected() {
        if (!resultsListRef) return;
        const selectedElement = resultsListRef.children[
            selectedIndex
        ] as HTMLElement;
        if (selectedElement) {
            selectedElement.scrollIntoView({ block: "nearest" });
        }
    }

    function handleSelect(item: SearchIndexItem) {
        console.log("[CourseSearch] Selected item:", item);
        isOpen = false;
        query = ""; // Clear query on select

        setTimeout(() => {
            const targetId = `activity-${item.activityId}`;
            const activityEl = document.getElementById(targetId);
            console.log(`[CourseSearch] Attempting scroll to ID: ${targetId}`, {
                found: !!activityEl,
            });

            if (activityEl) {
                activityEl.scrollIntoView({
                    behavior: "smooth",
                    block: "center",
                });

                // Highlight Activity
                activityEl.classList.add(
                    "ring-2",
                    "ring-blue-500",
                    "ring-offset-2",
                    "ring-offset-black",
                );

                // Deep Link Handling
                if (item.type === "heading" && item.anchorId) {
                    console.log(
                        `[CourseSearch] Processing deep link for anchor: ${item.anchorId}`,
                    );
                    const toggleBtn =
                        activityEl.querySelector('[role="button"]');

                    // Auto-expand if collapsed (check for html-content which indicates loaded content)
                    const contentExists =
                        !!activityEl.querySelector(".html-content");
                    console.log(
                        `[CourseSearch] Activity content exists? ${contentExists}`,
                    );

                    if (toggleBtn && !contentExists) {
                        console.log("[CourseSearch] Expanding activity...");
                        (toggleBtn as HTMLElement).click();
                    } else {
                        console.log(
                            "[CourseSearch] Activity already expanded or no toggle button.",
                        );
                    }

                    // Scroll to anchor
                    setTimeout(() => {
                        const anchor = document.getElementById(item.anchorId!);
                        console.log(
                            `[CourseSearch] Attempting scroll to Anchor: ${item.anchorId}`,
                            { found: !!anchor },
                        );
                        if (anchor) {
                            anchor.scrollIntoView({
                                behavior: "smooth",
                                block: "center",
                            });
                            anchor.classList.add("bg-yellow-500/30");
                            setTimeout(
                                () =>
                                    anchor.classList.remove("bg-yellow-500/30"),
                                2000,
                            );
                        } else {
                            console.warn(
                                `[CourseSearch] Anchor element ${item.anchorId} NOT FOUND.`,
                            );
                        }
                    }, 300);
                }

                setTimeout(() => {
                    activityEl.classList.remove(
                        "ring-2",
                        "ring-blue-500",
                        "ring-offset-2",
                        "ring-offset-black",
                    );
                }, 2000);
            }
        }, 300);
    }

    function getActivityIcon(modname: string) {
        switch (modname) {
            case "folder":
                return Folder;
            case "url":
                return Link;
            case "book":
                return Book;
            case "resource":
                return File;
            default:
                return FileText;
        }
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

<SearchTrigger onClick={() => (isOpen = true)} label="Search in course..." />

<SearchDialog
    {isOpen}
    bind:query
    onClose={() => (isOpen = false)}
    placeholder="Search for notes, resources, activities..."
    footerResultsCount={searchResults.length}
>
    <!-- Results -->
    {#if !query}
        <div class="p-8 text-center text-neutral-500 text-sm">
            <p>Type to search within this course content.</p>
        </div>
    {:else if searchResults.length === 0}
        <div class="p-8 text-center text-neutral-500 text-sm">
            <p>No matching activities found.</p>
        </div>
    {:else}
        <div class="flex flex-col gap-1" bind:this={resultsListRef}>
            {#each searchResults as result, index (result.activityId + (result.anchorId || ""))}
                {@const Icon = getActivityIcon(result.modname)}
                <button
                    onclick={() => handleSelect(result)}
                    onmouseenter={() => (selectedIndex = index)}
                    class={`w-full flex items-center justify-between px-3 py-3 rounded-lg transition-colors group text-left ${
                        index === selectedIndex
                            ? "bg-blue-600/10 text-white"
                            : "text-neutral-400 hover:bg-neutral-800 hover:text-neutral-200"
                    }`}
                >
                    <div class="flex items-center gap-3 min-w-0">
                        {#if result.type === "activity"}
                            <div
                                class={`p-2 rounded-md ${
                                    index === selectedIndex
                                        ? "bg-blue-600/20 text-blue-400"
                                        : "bg-neutral-800 border border-neutral-700 text-neutral-500"
                                }`}
                            >
                                <Icon size={16} />
                            </div>
                            <div class="min-w-0 flex-1">
                                <div class="flex items-center gap-2">
                                    <span class="font-medium truncate"
                                        >{result.text}</span
                                    >
                                    <span
                                        class={`text-[10px] px-1.5 py-0.5 rounded border ${
                                            index === selectedIndex
                                                ? "border-blue-500/30 text-blue-400 bg-blue-500/10"
                                                : "border-neutral-700 text-neutral-500 bg-neutral-800"
                                        }`}
                                    >
                                        {result.sectionName}
                                    </span>
                                </div>
                            </div>
                        {:else}
                            <div
                                class={`p-2 rounded-md ${
                                    index === selectedIndex
                                        ? "bg-blue-600/20 text-blue-400"
                                        : "bg-neutral-800 border border-neutral-700 text-neutral-500"
                                }`}
                            >
                                <Hash size={16} />
                            </div>
                            <div class="min-w-0 flex-1">
                                <div class="font-medium truncate">
                                    {result.text}
                                </div>
                                <div
                                    class="flex items-center gap-2 text-xs text-neutral-500"
                                >
                                    <span>in {result.activityName}</span>
                                </div>
                            </div>
                        {/if}
                    </div>
                    {#if index === selectedIndex}
                        <div class="flex items-center gap-2 text-blue-400">
                            <span class="text-xs">
                                {result.type === "activity"
                                    ? "Open"
                                    : "Jump to"}
                            </span>
                            <CornerDownLeft size={14} />
                        </div>
                    {/if}
                </button>
            {/each}
        </div>
    {/if}
</SearchDialog>
