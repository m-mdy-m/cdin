export interface Contributor {
  login: string;
  id: number;
  avatar_url: string;
  html_url: string;
  contributions: number;
}

export const FALLBACK_CONTRIBUTORS: Contributor[] = [
  {
    login: "m-mdy-m",
    id: 0,
    avatar_url: "",
    html_url: "https://github.com/m-mdy-m",
    contributions: 0,
  },
];

export async function fetchContributors(): Promise<Contributor[]> {
  const res = await fetch(
    "https://api.github.com/repos/m-mdy-m/cdin/contributors",
    { headers: { Accept: "application/vnd.github+json" } },
  );

  if (!res.ok) {
    throw new Error(`GitHub API returned ${res.status}`);
  }

  const data = (await res.json()) as Contributor[];

  return data.map((c) => ({
    login: c.login,
    id: c.id,
    avatar_url: c.avatar_url,
    html_url: c.html_url,
    contributions: c.contributions,
  }));
}
