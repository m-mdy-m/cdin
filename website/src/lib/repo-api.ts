import { fallbackContributers } from "@/consts/fallbackContributers";

const REPO_API_URL = "https://api.github.com/repos/m-mdy-m/cdin";
const CONTRIBUTORS_API_URL = `${REPO_API_URL}/contributors?per_page=100`;

export interface Contributor {
  login: string;
  id: number;
  avatar_url: string;
  html_url: string;
  contributions: number;
}

export interface RepoData {
  stars: number | null;
  contributors: Contributor[];
}

interface GitHubRepoResponse {
  stargazers_count: number;
}

interface GitHubContributorResponse {
  login: string;
  id: number;
  avatar_url: string;
  html_url: string;
  contributions: number;
}

export const FALLBACK_REPO_DATA: RepoData = {
  stars: null,
  contributors: fallbackContributers,
};

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url, {
    headers: { Accept: "application/vnd.github+json" },
  });

  if (!res.ok) {
    throw new Error(`GitHub API returned ${res.status}`);
  }

  return (await res.json()) as T;
}

function normalizeContributor(
  contributor: GitHubContributorResponse,
): Contributor {
  return {
    login: contributor.login,
    id: contributor.id,
    avatar_url: contributor.avatar_url,
    html_url: contributor.html_url,
    contributions: contributor.contributions,
  };
}

let repoDataPromise: Promise<RepoData> | undefined;

export function fetchRepoData(): Promise<RepoData> {
  if (repoDataPromise) return repoDataPromise;

  repoDataPromise = Promise.all([
    fetchJson<GitHubRepoResponse>(REPO_API_URL),
    fetchJson<GitHubContributorResponse[]>(CONTRIBUTORS_API_URL),
  ])
    .then(([repo, contributors]) => {
      if (typeof repo.stargazers_count !== "number") {
        throw new Error("GitHub API response did not include stargazers_count");
      }

      return {
        stars: repo.stargazers_count,
        contributors: contributors.map(normalizeContributor),
      };
    })
    .catch((error: unknown) => {
      repoDataPromise = undefined;
      throw error;
    });

  return repoDataPromise;
}
