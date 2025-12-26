<script lang="ts">
  import { Key, X } from 'lucide-svelte';
  import { backendClient } from '$lib/backendClient';

  let isOpen = $state(false);
  let token = $state('');
  let isLoading = $state(false);
  let message = $state<{ type: 'success' | 'error'; text: string } | null>(null);

  async function handleSubmit(e: Event) {
    e.preventDefault();
    setIsLoading(true);
    message = null;

    try {
      // Validate token using backendClient
      const result = await backendClient.validateToken(token);
      
      if (result.valid) {
        // Fetch user info to confirm and get name
        const loginResult = await backendClient.login(token);
        
        if (loginResult.success && loginResult.user) {
          // Store token in localStorage (add to existing if management needed, but for now specific flow)
          // The react app used cookies in addTokenAction, but mostly localStorage in client.
          // We'll stick to localStorage as primary.
          // Note: AddTokenButton in original app implies adding *another* token?
          // Or just setting THE token?
          // The React code said: "Add your Moodle API token... This works alongside your SSO session."
          
          localStorage.setItem('moodle_token', token);
          
          message = { type: 'success', text: `Token added! Welcome ${loginResult.user.fullname}` };
          token = '';
          
          setTimeout(() => {
            isOpen = false;
            window.location.reload(); 
          }, 2000);
        } else {
             message = { type: 'error', text: loginResult.error || 'Invalid token' };
        }
      } else {
        message = { type: 'error', text: 'Invalid token' };
      }
    } catch (e) {
      console.error(e);
      message = { type: 'error', text: 'Failed to verify token' };
    } finally {
      setIsLoading(false);
    }
  }
</script>

{#if !isOpen}
  <button
    onclick={() => isOpen = true}
    class="text-sm text-neutral-400 hover:text-white flex items-center gap-2 transition-colors"
    title="Add API Token"
  >
    <Key size={16} />
    <span class="hidden sm:inline">Add Token</span>
  </button>
{:else}
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
    <div class="bg-neutral-900 border border-neutral-800 rounded-lg p-6 max-w-md w-full">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-white">Add API Token</h2>
        <button
          onclick={() => isOpen = false}
          class="text-neutral-400 hover:text-white transition-colors"
        >
          <X size={20} />
        </button>
      </div>

      <p class="text-sm text-neutral-400 mb-4">
        Add your Moodle API token to enable faster navigation and downloads. This works alongside your SSO session.
      </p>

      <form onsubmit={handleSubmit} class="space-y-4">
        <div>
          <label for="token" class="block text-sm font-medium text-neutral-300 mb-2">
            API Token
          </label>
          <input
            id="token"
            type="text"
            bind:value={token}
            placeholder="a1b2c3d4e5f6..."
            class="w-full px-3 py-2 bg-black border border-neutral-700 rounded-lg text-white placeholder-neutral-500 focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
            disabled={isLoading}
          />
        </div>

        {#if message}
          <div
            class={`p-3 rounded-lg text-sm ${
              message.type === 'success'
                ? 'bg-green-500/10 text-green-400 border border-green-500/20'
                : 'bg-red-500/10 text-red-400 border border-red-500/20'
            }`}
          >
            {message.text}
          </div>
        {/if}

        <div class="flex gap-3">
          <button
            type="submit"
            disabled={isLoading || !token}
            class="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-neutral-700 disabled:cursor-not-allowed text-white rounded-lg transition-colors"
          >
            {isLoading ? 'Verifying...' : 'Add Token'}
          </button>
          <button
            type="button"
            onclick={() => isOpen = false}
            class="px-4 py-2 bg-neutral-800 hover:bg-neutral-700 text-white rounded-lg transition-colors"
          >
            Cancel
          </button>
        </div>
      </form>

      <p class="text-xs text-neutral-500 mt-4">
        Get your token from: Moodle → Profile → Preferences → Security keys
      </p>
    </div>
  </div>
{/if}
