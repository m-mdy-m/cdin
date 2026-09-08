import { useEffect, useState } from "react";
import { fetchContributors } from "@/lib/contributors";
import type { Contributor } from "@/lib/contributors";
import { fallbackContributers } from "@/consts/fallbackContributers";

export function useContributors() {
  const [data, setData] = useState<Contributor[]>([]);

  useEffect(() => {
    let cancelled = false;

    fetchContributors()
      .then((result) => {
        if (cancelled) return;
        console.log("contributors:", result);
        setData(result);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        console.warn(
          "Failed to fetch contributors, using fallback:",
          err instanceof Error ? err.message : err,
        );
        setData(fallbackContributers);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  return data;
}
