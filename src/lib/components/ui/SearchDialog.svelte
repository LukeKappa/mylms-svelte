<script lang="ts">
    import { Search, X } from "lucide-svelte";
    import { fade, scale } from "svelte/transition";
    import { cubicOut } from "svelte/easing";
    import type { Snippet } from "svelte";

    interface Props {
        isOpen: boolean;
        query: string;
        onClose: () => void;
        placeholder?: string;
        children?: Snippet; // Results slot
        footerResultsCount?: number;
    }

    let {
        isOpen,
        query = $bindable(),
        onClose,
        placeholder = "Search...",
        children,
        footerResultsCount = 0,
    }: Props = $props();

    let inputRef = $state<HTMLInputElement | null>(null);

    $effect(() => {
        if (isOpen && inputRef) {
            // Slight delay for animation
            setTimeout(() => inputRef?.focus(), 50);
        }
    });

    // Handle ESC on the dialog level as backup
    function handleKeydown(e: KeyboardEvent) {
        if (isOpen && e.key === "Escape") {
            e.stopPropagation(); // prevent bubbling if handled here?
            onClose();
        }
    }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if isOpen}
    <div
        class="fixed inset-0 z-50 flex items-start justify-center pt-[20vh] px-4"
    >
        <!-- Backdrop -->
        <!-- svelte-ignore a11y_click_events_have_key_events -->
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
            class="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onclick={onClose}
            transition:fade={{ duration: 200 }}
        ></div>

        <!-- Dialog -->
        <div
            class="relative w-full max-w-xl bg-neutral-900 border border-neutral-800 rounded-xl shadow-2xl overflow-hidden flex flex-col"
            transition:scale={{ start: 0.95, duration: 200, easing: cubicOut }}
        >
            <!-- Search Input -->
            <div
                class="flex items-center px-4 py-3 border-b border-neutral-800"
            >
                <Search size={20} class="text-neutral-500 mr-3" />
                <input
                    bind:this={inputRef}
                    type="text"
                    bind:value={query}
                    {placeholder}
                    class="flex-1 bg-transparent border-none outline-none text-white placeholder-neutral-600 text-lg"
                />
                <button
                    onclick={onClose}
                    class="p-1 text-neutral-500 hover:text-white rounded-md transition-colors"
                >
                    <span class="text-xs mr-2 font-mono">ESC</span>
                    <X size={18} class="inline" />
                </button>
            </div>

            <!-- Content (Results) -->
            <div class="max-h-[60vh] overflow-y-auto p-2">
                {@render children?.()}
            </div>

            <!-- Footer -->
            {#if footerResultsCount > 0}
                <div
                    class="px-4 py-2 bg-neutral-900/50 border-t border-neutral-800 text-[10px] text-neutral-500 flex justify-between items-center"
                >
                    <div class="flex gap-3">
                        <span>
                            <kbd
                                class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700"
                                >↑</kbd
                            >
                            <kbd
                                class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700"
                                >↓</kbd
                            > to navigate
                        </span>
                        <span>
                            <kbd
                                class="font-mono bg-neutral-800 px-1 rounded border border-neutral-700"
                                >Enter</kbd
                            > to select
                        </span>
                    </div>
                    <span>
                        <span class="text-white font-medium"
                            >{footerResultsCount}</span
                        > results
                    </span>
                </div>
            {/if}
        </div>
    </div>
{/if}
