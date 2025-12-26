<script lang="ts">
  import { Pause, Play, X } from 'lucide-svelte';

  interface DownloadProgress {
    current: number;
    total: number;
    percentage: number;
    status: string;
    speed?: number; // items per second
    estimatedTimeRemaining?: number; // seconds
  }

  interface Props {
    progress: DownloadProgress;
    onPause?: () => void;
    onResume?: () => void;
    onCancel?: () => void;
    isPaused?: boolean;
    isDownloading?: boolean;
  }

  let { 
    progress, 
    onPause, 
    onResume, 
    onCancel, 
    isPaused = false, 
    isDownloading = false 
  }: Props = $props();

  let localSpeed = $state(0);
  let localETA = $state(0);

  $effect(() => {
    if (progress.speed !== undefined) {
      localSpeed = progress.speed;
    }
    if (progress.estimatedTimeRemaining !== undefined) {
      localETA = progress.estimatedTimeRemaining;
    }
  });

  function formatTime(seconds: number): string {
    if (seconds < 60) return `${Math.round(seconds)}s`;
    const minutes = Math.floor(seconds / 60);
    const secs = Math.round(seconds % 60);
    return `${minutes}m ${secs}s`;
  }
</script>

{#if isDownloading || progress.percentage > 0}
  <div class="fixed bottom-4 right-4 w-96 bg-neutral-900 border border-neutral-800 rounded-lg shadow-2xl p-4 z-50">
    <!-- Header -->
    <div class="flex items-center justify-between mb-3">
      <div class="flex items-center gap-2">
        <div class="w-2 h-2 rounded-full bg-blue-500 animate-pulse"></div>
        <h3 class="text-sm font-medium text-white">
          {isPaused ? 'Download Paused' : progress.status}
        </h3>
      </div>
      
      <!-- Controls -->
      <div class="flex items-center gap-1">
        {#if isDownloading}
          {#if isPaused}
            <button
              onclick={onResume}
              class="p-1.5 hover:bg-neutral-800 rounded transition-colors"
              title="Resume"
            >
              <Play class="w-4 h-4 text-green-500" />
            </button>
          {:else}
            <button
              onclick={onPause}
              class="p-1.5 hover:bg-neutral-800 rounded transition-colors"
              title="Pause"
            >
              <Pause class="w-4 h-4 text-yellow-500" />
            </button>
          {/if}
        {/if}
        <button
          onclick={onCancel}
          class="p-1.5 hover:bg-neutral-800 rounded transition-colors"
          title="Cancel"
        >
          <X class="w-4 h-4 text-red-500" />
        </button>
      </div>
    </div>

    <!-- Progress Bar -->
    <div class="relative w-full h-2 bg-neutral-800 rounded-full overflow-hidden mb-3">
      <div
        class="absolute top-0 left-0 h-full bg-gradient-to-r from-blue-500 to-blue-600 transition-all duration-300 ease-out"
        style="width: {progress.percentage}%"
      ></div>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 gap-3 text-xs">
      <div>
        <p class="text-neutral-400">Progress</p>
        <p class="text-white font-medium">
          {progress.current} / {progress.total} ({progress.percentage}%)
        </p>
      </div>
      
      {#if localSpeed > 0}
        <div>
          <p class="text-neutral-400">Speed</p>
          <p class="text-white font-medium">
            {localSpeed.toFixed(1)} items/s
          </p>
        </div>
      {/if}
      
      {#if localETA > 0 && !isPaused}
        <div class="col-span-2">
          <p class="text-neutral-400">Estimated time remaining</p>
          <p class="text-white font-medium">{formatTime(localETA)}</p>
        </div>
      {/if}
    </div>

    <!-- Paused Message -->
    {#if isPaused}
      <div class="mt-3 p-2 bg-yellow-500/10 border border-yellow-500/20 rounded text-xs text-yellow-400">
        Download paused. Click resume to continue.
      </div>
    {/if}
  </div>
{/if}
