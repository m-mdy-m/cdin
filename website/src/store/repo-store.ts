import { create } from "zustand";
import { FALLBACK_REPO_DATA, fetchRepoData } from "@/lib/repo-api";
import type { RepoData } from "@/lib/repo-api";

type RepoStore = RepoData & {
  isLoading: boolean;
  hasFetched: boolean;
  error: string | null;
  fetchRepo: () => Promise<void>;
};

export const useRepoStore = create<RepoStore>((set, get) => ({
  ...FALLBACK_REPO_DATA,
  isLoading: false,
  hasFetched: false,
  error: null,

  fetchRepo: async () => {
    const { isLoading, hasFetched } = get();
    if (isLoading || hasFetched) return;

    set({ isLoading: true, error: null });

    try {
      const data = await fetchRepoData();
      set({
        ...data,
        isLoading: false,
        hasFetched: true,
        error: null,
      });
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : "Unknown GitHub API error";

      console.error("Failed to fetch cdin GitHub data:", error);
      set({
        ...FALLBACK_REPO_DATA,
        isLoading: false,
        hasFetched: false,
        error: message,
      });
    }
  },
}));
