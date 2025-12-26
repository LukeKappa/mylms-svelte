<script lang="ts">
  import {
    ChevronDown,
    ChevronRight,
    ExternalLink,
    FileText,
    Link as LinkIcon,
    FileQuestion,
    MessageSquare,
    BookText,
    FolderOpen,
    Database,
    Calendar,
  } from "lucide-svelte";

  import katex from "katex";
  import "katex/dist/katex.min.css";
  import "$lib/moodle-content.css";

  import { backendClient } from "$lib/backendClient";
  import type { Activity } from "$lib/backendClient";
  import { dbService } from "$lib/indexedDB";
  import { isMoodleUrl } from "$lib/config/moodle";
  import ScrollToTopButton from "./ScrollToTopButton.svelte";

  interface Props {
    activity: Activity;
  }

  let { activity }: Props = $props();

  let isExpanded = $state(false);
  let isLoading = $state(false);
  let isPrefetching = $state(false);
  let content = $state<string | null>(null);
  let toc = $state<{ id: string; text: string; level: number }[]>([]);
  let error = $state<string | null>(null);
  let currentUrl = $state(activity.url);

  $effect(() => {
    currentUrl = activity.url;
  });

  let prefetchTimeout: NodeJS.Timeout | null = null;
  let hasPrefetched = false;

  const iconMap: Record<string, any> = {
    resource: FileText,
    assign: FileQuestion,
    quiz: FileQuestion,
    forum: MessageSquare,
    page: BookText,
    url: LinkIcon,
    folder: FolderOpen,
    data: Database,
    database: Database,
    attendance: Calendar,
    book: BookText,
    lesson: BookText,
  };

  const Icon = $derived(iconMap[activity.modname] || FileText);

  // --- Helper Functions (ported from React) ---

  function renderMathInHtml(html: string): string {
    if (!html) return "";
    let processed = html;

    // Decode HTML entities
    processed = processed.replace(/&nbsp;/g, " ");
    processed = processed.replace(/&amp;nbsp;/g, " ");
    processed = processed.replace(/&amp;/g, "&");
    processed = processed.replace(/&lt;/g, "<");
    processed = processed.replace(/&gt;/g, ">");
    processed = processed.replace(/&quot;/g, '"');
    processed = processed.replace(/&#(\d+);/g, (_, code) =>
      String.fromCharCode(parseInt(code)),
    );

    // Fix backslashes
    processed = processed.replace(/\\\\([a-zA-Z])/g, "\\$1");

    const safeRender = (tex: string, displayMode: boolean): string => {
      try {
        let cleanTex = tex
          .replace(/&amp;/g, "&")
          .replace(/&lt;/g, "<")
          .replace(/&gt;/g, ">")
          .replace(/\s+/g, " ")
          .trim();

        return katex.renderToString(cleanTex, {
          displayMode,
          throwOnError: false,
          strict: false,
          trust: true,
          output: "html",
        });
      } catch (e) {
        console.warn("KaTeX render failed:", e);
        return `<span class="math-fallback">${tex}</span>`;
      }
    };

    processed = processed.replace(/\$\$([\s\S]+?)\$\$/g, (_, tex) =>
      safeRender(tex, true),
    );

    processed = processed.replace(
      /([^\\$]|^)\$([^$\n]+?)\$/g,
      (match, prefix, tex) => {
        if (/^\d+(\.\d+)?$/.test(tex.trim())) return match;
        return prefix + safeRender(tex, false);
      },
    );

    processed = processed.replace(/\\\((.+?)\\\)/g, (_, tex) =>
      safeRender(tex, false),
    );
    processed = processed.replace(/\\\[([\s\S]+?)\\\]/g, (_, tex) =>
      safeRender(tex, true),
    );
    processed = processed.replace(
      /\\begin\{equation\}([\s\S]+?)\\end\{equation\}/g,
      (_, tex) => safeRender(tex.trim(), true),
    );
    processed = processed.replace(
      /\\begin\{align\*?\}([\s\S]+?)\\end\{align\*?\}/g,
      (_, tex) =>
        safeRender(`\\begin{aligned}${tex.trim()}\\end{aligned}`, true),
    );

    return processed;
  }

  function getUniqueIdFromUrl(url: string): string {
    let hash = 0;
    for (let i = 0; i < url.length; i++) {
      const char = url.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(36);
  }

  function processHtmlForTOC(html: string, uniquePrefix: string) {
    if (!html) return { html: "", toc: [] };

    const newToc: { id: string; text: string; level: number }[] = [];
    let headingCount = 0;

    const processedHtml = html.replace(
      /\<(h[1-6])([^\>]*)\>(.*?)\<\/\1\>/gi,
      (match, tag, attrs, contentStr) => {
        const level = parseInt(tag.charAt(1));

        // Temporary div to extract text
        if (typeof document !== "undefined") {
          const tempDiv = document.createElement("div");
          tempDiv.innerHTML = contentStr;
          const text = tempDiv.textContent?.trim() || "";

          if (!text) return match;

          const id = `heading-${uniquePrefix}-${headingCount++}`;
          newToc.push({ id, text, level });

          if (attrs.includes("id=")) {
            const idMatch = attrs.match(/id=["']([^"']+)["']/);
            if (idMatch) {
              const uniqueId = `${uniquePrefix}-${idMatch[1]}`;
              newToc[newToc.length - 1].id = uniqueId;
              return `<${tag} id="${uniqueId}"${attrs.replace(/id=["'][^"']+["']/, "")}>${contentStr}</${tag}>`;
            }
          }

          return `<${tag} id="${id}"${attrs}>${contentStr}</${tag}>`;
        }
        return match;
      },
    );

    return { html: processedHtml, toc: newToc };
  }

  // --- Logic ---

  async function fetchContent(url: string) {
    setIsLoading(true);
    setError(null);

    try {
      // IndexedDB check
      const cachedContent = await dbService.getActivity(url);
      if (cachedContent) {
        console.log("[ActivityItem] Cache hit (IndexedDB):", url);
        const { html, toc: newToc } = processHtmlForTOC(
          cachedContent,
          getUniqueIdFromUrl(url),
        );
        setContent(html);
        setToc(newToc);
        setIsLoading(false);
        return;
      }

      const token = localStorage.getItem("moodle_token");
      if (!token) {
        setError("Not authenticated");
        setIsLoading(false);
        return;
      }

      console.log("[ActivityItem] Fetching from Rust backend:", url);
      const result = await backendClient.getActivityContent(token, url);

      if (!result.success || result.error) {
        setError(result.error || "Failed to fetch content");
      } else if (result.content) {
        const { html, toc: newToc } = processHtmlForTOC(
          result.content,
          getUniqueIdFromUrl(url),
        );
        setContent(html);
        setToc(newToc);

        dbService
          .saveActivity(url, result.content)
          .catch((e) => console.error("Failed to save to DB:", e));
      }
    } catch (err) {
      console.error("[ActivityItem] Error:", err);
      setError("Failed to load content");
    } finally {
      setIsLoading(false);
    }
  }

  function handleMouseEnter() {
    if (content || isLoading || isPrefetching || hasPrefetched) return;

    prefetchTimeout = setTimeout(async () => {
      if (content || isLoading || hasPrefetched) return;

      hasPrefetched = true;
      isPrefetching = true;

      try {
        const cachedContent = await dbService.getActivity(currentUrl);
        if (cachedContent) {
          const { html, toc: newToc } = processHtmlForTOC(
            cachedContent,
            getUniqueIdFromUrl(currentUrl),
          );
          setContent(html);
          setToc(newToc);
          console.log("[Prefetch] Cache hit:", activity.name);
          return;
        }

        const token = localStorage.getItem("moodle_token");
        if (!token) return;

        console.log("[Prefetch] Starting:", activity.name);
        const result = await backendClient.getActivityContent(
          token,
          currentUrl,
        );

        if (result.success && result.content) {
          const { html, toc: newToc } = processHtmlForTOC(
            result.content,
            getUniqueIdFromUrl(currentUrl),
          );
          setContent(html);
          setToc(newToc);
          dbService
            .saveActivity(currentUrl, result.content)
            .catch(console.error);
          console.log("[Prefetch] Complete:", activity.name);
        }
      } catch (e) {
        console.warn("[Prefetch] Failed:", e);
      } finally {
        isPrefetching = false;
      }
    }, 200);
  }

  function handleMouseLeave() {
    if (prefetchTimeout) {
      clearTimeout(prefetchTimeout);
      prefetchTimeout = null;
    }
  }

  async function handleToggle() {
    if (!isExpanded) {
      if (!content && !isLoading && !isPrefetching) {
        await fetchContent(currentUrl);
      }
    }
    isExpanded = !isExpanded;
  }

  async function handleContentClick(e: MouseEvent) {
    const target = e.target as HTMLElement;
    const link = target.closest("a");

    if (link && link.href) {
      // TOC Link
      if (link.hash && link.hash.startsWith("#heading-")) {
        e.preventDefault();
        const id = link.hash.substring(1);
        const element = document.getElementById(id);
        if (element) {
          element.scrollIntoView({ behavior: "smooth" });
        }
        return;
      }

      // Internal Moodle Link
      if (isMoodleUrl(link.href)) {
        e.preventDefault();

        // Update URL and fetch
        currentUrl = link.href;
        await fetchContent(link.href);

        const contentArea = (e.currentTarget as HTMLElement).querySelector(
          ".activity-content",
        );
        if (contentArea) {
          contentArea.scrollIntoView({ behavior: "smooth", block: "nearest" });
        }
      }
    }
  }

  function setIsLoading(val: boolean) {
    isLoading = val;
  }
  function setError(val: string | null) {
    error = val;
  }
  function setContent(val: string | null) {
    content = val;
  }
  function setToc(val: typeof toc) {
    toc = val;
  }
</script>

<div
  id={`activity-${activity.id}`}
  class="border-b border-neutral-800 last:border-b-0"
>
  <!-- Activity Header -->
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    role="button"
    tabindex="0"
    onclick={handleToggle}
    onmouseenter={handleMouseEnter}
    onmouseleave={handleMouseLeave}
    class="flex items-center gap-4 p-4 hover:bg-neutral-800/50 transition-colors cursor-pointer group"
  >
    <div
      class="p-2 bg-neutral-800 rounded-lg text-neutral-400 group-hover:bg-white group-hover:text-black transition-colors flex-shrink-0"
    >
      <Icon size={20} />
    </div>

    <div class="flex-1 min-w-0">
      <p class="text-white font-medium">{activity.name}</p>
      <p class="text-xs text-neutral-500 uppercase tracking-wider">
        {activity.type}
      </p>
    </div>

    <div class="flex items-center gap-2 flex-shrink-0">
      <a
        href={activity.url}
        target="_blank"
        rel="noopener noreferrer"
        onclick={(e) => e.stopPropagation()}
        class="p-2 text-neutral-600 hover:text-neutral-400 transition-colors"
        title="Open in new tab"
      >
        <ExternalLink size={16} />
      </a>

      {#if isExpanded}
        <ChevronDown size={20} class="text-neutral-400" />
      {:else}
        <ChevronRight size={20} class="text-neutral-400" />
      {/if}
    </div>
  </div>

  <!-- Expandable Content -->
  {#if isExpanded}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="border-t border-neutral-800/50" onclick={handleContentClick}>
      {#if isLoading}
        <div class="py-8 text-center">
          <div
            class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-white"
          ></div>
          <p class="mt-2 text-neutral-500 text-sm">Loading content...</p>
        </div>
      {:else if error}
        <div class="py-4 text-center text-red-400 text-sm">
          <p>{error}</p>
        </div>
      {:else if content}
        <div class="relative">
          {#if toc.length > 0}
            <div
              id="table-of-contents"
              class="mb-6 p-4 bg-neutral-800/50 rounded-lg border border-neutral-800"
            >
              <p
                class="text-sm font-medium text-neutral-400 mb-2 uppercase tracking-wider"
              >
                Table of Contents
              </p>
              <ul class="space-y-1">
                {#each toc as item}
                  <li style="padding-left: {(item.level - 1) * 0.75}rem">
                    <a
                      href="#{item.id}"
                      class="text-sm text-blue-400 hover:text-blue-300 hover:underline block py-0.5"
                    >
                      {item.text}
                    </a>
                  </li>
                {/each}
              </ul>
            </div>
          {/if}

          <div class="html-content p-4 bg-neutral-900 w-full">
            {@html renderMathInHtml(content)}
          </div>
          <ScrollToTopButton />
        </div>
      {/if}
    </div>
  {/if}
</div>
