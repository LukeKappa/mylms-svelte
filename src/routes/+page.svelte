<script lang="ts">
  import { goto } from '$app/navigation';
  import { backendClient } from '$lib/backendClient';
  import { onMount } from 'svelte';

  let token = $state('');
  let isLoading = $state(false);
  let error = $state<string | null>(null);

  // Check for existing token
  onMount(async () => {
    const storedToken = localStorage.getItem('moodle_token');
    if (storedToken) {
      await validateAndRedirect(storedToken);
    }
  });

  async function validateAndRedirect(tokenToTest: string) {
    isLoading = true;
    try {
      const result = await backendClient.login(tokenToTest);
      if (result.success) {
        localStorage.setItem('moodle_token', tokenToTest);
        if (result.user) {
          localStorage.setItem('moodle_user', JSON.stringify(result.user));
        }
        await goto('/dashboard');
      } else {
        error = result.error || 'Invalid token';
        // Clear invalid token
        if (localStorage.getItem('moodle_token') === tokenToTest) {
          localStorage.removeItem('moodle_token');
        }
      }
    } catch (e) {
      console.error(e);
      error = 'Failed to connect to backend';
    } finally {
      isLoading = false;
    }
  }

  async function handleSubmit(e: Event) {
    e.preventDefault();
    await validateAndRedirect(token);
  }
</script>

<div class="min-h-screen flex items-center justify-center p-4 bg-black">
  <div class="w-full max-w-md space-y-8">
    <div class="text-center">
      <h1 class="text-4xl font-bold tracking-tight text-white mb-2">MyLocalMS</h1>
      <p class="text-neutral-400">Enter your Moodle API token to continue</p>
    </div>

    <div class="bg-neutral-900 border border-neutral-800 rounded-xl p-8 shadow-2xl">
      <form onsubmit={handleSubmit} class="space-y-6">
        <div>
          <label for="token" class="block text-sm font-medium text-neutral-300 mb-2">
            API Token
          </label>
          <input
            id="token"
            type="text"
            bind:value={token}
            placeholder="Moodle Token..."
            class="w-full px-4 py-3 bg-black border border-neutral-700 rounded-lg text-white placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all font-mono"
            required
            disabled={isLoading}
          />
        </div>

        {#if error}
          <div class="p-4 bg-red-900/20 border border-red-800 rounded-lg text-red-400 text-sm">
            {error}
          </div>
        {/if}

        <button
          type="submit"
          disabled={isLoading || !token}
          class="w-full py-3 bg-blue-600 hover:bg-blue-700 disabled:bg-neutral-800 disabled:text-neutral-500 disabled:cursor-not-allowed text-white font-medium rounded-lg transition-all flex items-center justify-center gap-2"
        >
          {#if isLoading}
            <div class="h-5 w-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
            <span>Verifying...</span>
          {:else}
            Connect
          {/if}
        </button>
      </form>

      <div class="mt-6 text-center text-xs text-neutral-500">
        <p>Your token is stored locally and sent only to your Moodle instance.</p>
      </div>
    </div>
  </div>
</div>
