<script lang="ts">
  import { Filter, Download, CheckCircle, Loader2, Trash2, X, Search, FileDown } from 'lucide-svelte';
  import type { Section } from '$lib/backendClient';

  interface Props {
    sections: Section[];
    visibleSections: Set<string>;
    onToggleSectionVisibility: (sectionName: string) => void;
    onToggleAllSections: () => void;
    
    availableActivityTypes: string[];
    visibleActivityTypes: Set<string>;
    onToggleActivityType: (type: string) => void;
    onToggleAllActivityTypes: () => void;
    
    searchQuery: string;
    onSearchChange: (query: string) => void;
    
    isSyncing: boolean;
    syncStatus: 'idle' | 'syncing' | 'success' | 'error';
    onSync: () => void;
    onCancelSync: () => void;
    totalActivities: number;
    
    clearCacheStatus: 'idle' | 'clearing' | 'success' | 'error';
    onClearCache: () => void;
    
    isExporting?: boolean;
    onExportPdf?: () => void;
  }

  let {
    sections,
    visibleSections,
    onToggleSectionVisibility,
    onToggleAllSections,
    availableActivityTypes,
    visibleActivityTypes,
    onToggleActivityType,
    onToggleAllActivityTypes,
    searchQuery,
    onSearchChange,
    isSyncing,
    syncStatus,
    onSync,
    onCancelSync,
    totalActivities,
    clearCacheStatus,
    onClearCache,
    isExporting,
    onExportPdf
  }: Props = $props();

  let isFilterOpen = $state(false);
  let isTypeFilterOpen = $state(false);
  let searchInputRef: HTMLInputElement | null = null;

  $effect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        searchInputRef?.focus();
      }
    };

    if (typeof window !== 'undefined') {
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }
  });

  const activityTypes = [
    { id: 'book', label: '📖 Notes (Book)', default: true },
    { id: 'page', label: '📄 Pages', default: false },
    { id: 'resource', label: '📎 Resources', default: false },
    { id: 'folder', label: '📁 Folders', default: false },
    { id: 'lesson', label: '📚 Lessons', default: false },
    { id: 'url', label: '🔗 URLs', default: false },
  ];
</script>

<div class="flex flex-col gap-3 w-full md:w-auto">
  <div class="flex items-center gap-2 flex-wrap md:flex-nowrap">
    <!-- Search Bar -->
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <div class="relative w-full md:w-auto group">
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-neutral-500 group-hover:text-neutral-300 transition-colors">
        <Search size={14} />
      </div>
      <input
        bind:this={searchInputRef}
        type="text"
        value={searchQuery}
        oninput={(e) => onSearchChange(e.currentTarget.value)}
        placeholder="Search..."
        class="w-full md:w-64 bg-neutral-900 border border-neutral-800 text-white text-sm rounded-md pl-9 pr-16 py-1.5 focus:outline-none focus:border-neutral-700 placeholder-neutral-500 hover:border-neutral-700 transition-all"
      />
      <div class="absolute inset-y-0 right-0 pr-2 flex items-center pointer-events-none">
        <kbd class="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-mono bg-neutral-800 rounded border border-neutral-700 text-neutral-400 group-hover:text-neutral-300 transition-colors">
          Ctrl K
        </kbd>
      </div>
    </div>
    
    <!-- Sync/Cancel Button -->
    {#if isSyncing}
      <button
        onclick={onCancelSync}
        class="flex items-center justify-center w-10 h-10 rounded-lg transition-colors border bg-red-900/30 border-red-800 text-red-400 hover:bg-red-900/50"
        title="Cancel Sync"
      >
        <X size={18} />
      </button>
    {:else}
      <button
        onclick={onSync}
        disabled={syncStatus === 'success'}
        class={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors border ${
          syncStatus === 'success' 
            ? 'bg-green-900/30 border-green-800 text-green-400'
            : syncStatus === 'error'
            ? 'bg-red-900/30 border-red-800 text-red-400'
            : 'bg-neutral-800 hover:bg-neutral-700 text-white border-neutral-700'
        }`}
        title={syncStatus === 'success' ? 'Synced' : syncStatus === 'error' ? 'Sync Error' : 'Download Offline'}
      >
        {#if syncStatus === 'success'}
          <CheckCircle size={18} />
        {:else if syncStatus === 'error'}
          <X size={18} />
        {:else}
          <Download size={18} />
        {/if}
      </button>
    {/if}

    <!-- Export PDF Button -->
    {#if onExportPdf}
      <button
        onclick={onExportPdf}
        disabled={isExporting}
        class={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors border ${
          isExporting
            ? 'bg-blue-900/30 border-blue-800 text-blue-400'
            : 'bg-neutral-800 hover:bg-neutral-700 text-white border-neutral-700'
        }`}
        title="Export as PDF"
      >
        {#if isExporting}
          <Loader2 size={18} class="animate-spin" />
        {:else}
          <FileDown size={18} />
        {/if}
      </button>
    {/if}

    <!-- Clear Cache Button -->
    <button
      onclick={onClearCache}
      disabled={clearCacheStatus === 'clearing'}
      class={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors border ${
        clearCacheStatus === 'success'
          ? 'bg-green-900/30 border-green-800 text-green-400'
          : clearCacheStatus === 'error'
          ? 'bg-red-900/30 border-red-800 text-red-400'
          : 'bg-neutral-800 hover:bg-neutral-700 text-white border-neutral-700'
      }`}
      title="Clear Cache"
    >
      {#if clearCacheStatus === 'clearing'}
        <Loader2 size={18} class="animate-spin" />
      {:else if clearCacheStatus === 'success'}
        <CheckCircle size={18} />
      {:else}
        <Trash2 size={18} />
      {/if}
    </button>

    <!-- Section Filter Dropdown -->
    <div class="relative">
      <button
        onclick={() => isFilterOpen = !isFilterOpen}
        class={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors border ${
          isFilterOpen ? 'bg-neutral-700 border-neutral-600' : 'bg-neutral-800 hover:bg-neutral-700 border-neutral-700'
        } text-white`}
        title="Filter Sections"
      >
        <Filter size={18} />
      </button>

      {#if isFilterOpen}
        <div class="absolute right-0 mt-2 w-72 bg-neutral-900 border border-neutral-800 rounded-xl shadow-2xl z-50 overflow-hidden">
          <div class="p-3 border-b border-neutral-800 flex justify-between items-center bg-neutral-900">
            <span class="text-sm font-medium text-white">Select Sections</span>
            <button 
              onclick={onToggleAllSections}
              class="text-xs text-blue-400 hover:text-blue-300"
            >
              {visibleSections.size === sections.length ? 'Deselect All' : 'Select All'}
            </button>
          </div>
          <div class="max-h-96 overflow-y-auto p-2 space-y-1">
            {#each sections as section (section.name)}
              <label 
                class="flex items-center gap-3 p-2 hover:bg-neutral-800 rounded-lg cursor-pointer transition-colors"
              >
                <div class={`w-5 h-5 rounded border flex items-center justify-center transition-colors ${
                  visibleSections.has(section.name) 
                    ? 'bg-blue-600 border-blue-600' 
                    : 'border-neutral-600 bg-transparent'
                }`}>
                  {#if visibleSections.has(section.name)}
                    <svg class="w-3.5 h-3.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                <input
                  type="checkbox"
                  class="hidden"
                  checked={visibleSections.has(section.name)}
                  onchange={() => onToggleSectionVisibility(section.name)}
                />
                <span class={`text-sm truncate ${
                  visibleSections.has(section.name) ? 'text-white' : 'text-neutral-400'
                }`}>
                  {section.name}
                </span>
              </label>
            {/each}
          </div>
        </div>
      {/if}
    </div>

    <!-- Activity Type Filter -->
    <div class="relative">
      <button
        onclick={() => isTypeFilterOpen = !isTypeFilterOpen}
        class={`flex items-center justify-center w-10 h-10 rounded-lg transition-colors border ${
          isTypeFilterOpen ? 'bg-neutral-700 border-neutral-600' : 'bg-neutral-800 hover:bg-neutral-700 border-neutral-700'
        } text-white`}
        title="Filter Activity Types"
      >
        <div class="relative">
          <Filter size={18} />
          {#if visibleActivityTypes.size > 0}
            <span class="absolute -top-2 -right-2 w-4 h-4 bg-blue-600 text-[10px] flex items-center justify-center rounded-full border border-neutral-900">
              {visibleActivityTypes.size}
            </span>
          {/if}
        </div>
      </button>

      {#if isTypeFilterOpen}
        <div class="absolute right-0 mt-2 w-72 bg-neutral-900 border border-neutral-800 rounded-xl shadow-2xl z-50 overflow-hidden">
          <div class="p-3 border-b border-neutral-800 flex justify-between items-center bg-neutral-900">
            <span class="text-sm font-medium text-white">Select Activity Types</span>
            <button 
              onclick={onToggleAllActivityTypes}
              class="text-xs text-blue-400 hover:text-blue-300"
            >
              {visibleActivityTypes.size === 6 ? 'Reset to Notes' : 'Select All'}
            </button>
          </div>
          <div class="max-h-96 overflow-y-auto p-2 space-y-1">
            {#each activityTypes.filter(type => availableActivityTypes.includes(type.id)) as type (type.id)}
              <label 
                class="flex items-center gap-3 p-2 hover:bg-neutral-800 rounded-lg cursor-pointer transition-colors"
              >
                <div class={`w-5 h-5 rounded border flex items-center justify-center transition-colors ${
                  visibleActivityTypes.has(type.id) 
                    ? 'bg-blue-600 border-blue-600' 
                    : 'border-neutral-600 bg-transparent'
                }`}>
                  {#if visibleActivityTypes.has(type.id)}
                    <svg class="w-3.5 h-3.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  {/if}
                </div>
                <input
                  type="checkbox"
                  class="hidden"
                  checked={visibleActivityTypes.has(type.id)}
                  onchange={() => onToggleActivityType(type.id)}
                />
                <span class={`text-sm flex items-center gap-2 ${
                  visibleActivityTypes.has(type.id) ? 'text-white' : 'text-neutral-400'
                }`}>
                  {type.label}
                  {#if type.default}
                    <span class="text-[10px] px-1.5 py-0.5 bg-green-900/30 text-green-400 rounded border border-green-800">
                      DEFAULT
                    </span>
                  {/if}
                </span>
              </label>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  </div>

  <!-- Progress Bar - Shows when syncing -->
  {#if isSyncing}
    <div class="w-full">
      <div class="flex items-center justify-between text-xs text-neutral-400 mb-1.5">
        <span>Downloading {totalActivities} {totalActivities === 1 ? 'activity' : 'activities'}...</span>
        <span class="flex items-center gap-1">
          <Loader2 size={12} class="animate-spin" />
          In progress
        </span>
      </div>

      <div class="h-2 bg-neutral-800 rounded-full overflow-hidden border border-neutral-700">
        <div class="h-full bg-gradient-to-r from-neutral-400 via-neutral-300 to-neutral-400 animate-pulse relative">
          <!-- Animated shimmer effect -->
          <div class="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer"></div>
        </div>
      </div>
      <style>
        @keyframes shimmer {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(100%); }
        }
        .animate-shimmer {
          animation: shimmer 2s infinite;
        }
      </style>
    </div>
  {/if}
</div>
