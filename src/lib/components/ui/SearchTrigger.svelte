<script lang="ts">
    import { Search } from "lucide-svelte";
    import { fade, scale } from "svelte/transition";
    import { cubicOut } from "svelte/easing";

    interface Props {
        onClick: () => void;
        label?: string;
        shortcut?: string;
    }

    let { onClick, label = "Search...", shortcut = "Ctrl K" }: Props = $props();
</script>

<!-- Desktop Trigger -->
<button
    onclick={onClick}
    in:scale={{ start: 0.95, duration: 200, easing: cubicOut }}
    out:fade={{ duration: 100 }}
    class="hidden md:flex items-center gap-2 px-3 py-1.5 bg-neutral-900 border border-neutral-800 rounded-md text-neutral-500 hover:text-neutral-300 hover:border-neutral-700 transition-all text-sm group w-64 cursor-text"
>
    <Search size={14} class="group-hover:text-white transition-colors" />
    <span class="flex-1 text-left">{label}</span>
    <kbd
        class="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-mono bg-neutral-800 rounded border border-neutral-700 text-neutral-400 group-hover:text-neutral-300 transition-colors"
    >
        {shortcut}
    </kbd>
</button>

<!-- Mobile Trigger -->
<button
    onclick={onClick}
    class="md:hidden p-2 text-neutral-400 hover:text-white"
>
    <Search size={20} />
</button>
