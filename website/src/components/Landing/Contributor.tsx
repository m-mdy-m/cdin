import { useContributors } from "@/hooks/useContributors";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { GitCommit } from "lucide-react";
import { Button } from "../ui/button";
import { useState } from "react";

const COLLAPSED_COUNT = 8;

export default function Contributors() {
  const contributors = useContributors();
  const [collapsed, setCollapsed] = useState(true);

  const maxContributions = Math.max(
    ...contributors.map((c) => c.contributions),
  );

  const extra = contributors.length - COLLAPSED_COUNT;
  const visibleContributers = collapsed
    ? contributors.slice(0, COLLAPSED_COUNT)
    : contributors;

  return (
    <div className="py-10 border-t md:px-10 px-4">
      <h1 className="lg:text-2xl font-semibold text-xl">Contributers</h1>
      <h6 className="mb-8 mt-0 text-muted-foreground text-sm">
        {contributors.length} people who helped shape cdin.{" "}
      </h6>

      <section className="flex items-center flex-wrap justify-center gap-4">
        {visibleContributers.map((c) => {
          const size = 32 + (c.contributions / maxContributions) * 48;
          return (
            <Tooltip key={c.id}>
              <TooltipTrigger
                className="cursor-pointer border-2 md:border-border border-primary rounded-full duration-150 hover:scale-110 hover:border-primary"
                style={{
                  width: Math.floor(size),
                  height: Math.floor(size),
                }}
              >
                <a href={c.html_url} target="_blank" rel="noreferrer">
                  <img
                    src={c.avatar_url}
                    alt={c.login}
                    className="rounded-full"
                  />
                </a>
              </TooltipTrigger>
              <TooltipContent>
                {c.contributions} <GitCommit />
              </TooltipContent>
            </Tooltip>
          );
        })}

        {extra > 0 && (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="secondary"
                size="default"
                onClick={() => setCollapsed((v) => !v)}
                aria-expanded={!collapsed}
                aria-label={
                  collapsed
                    ? `Show ${extra} more contributors`
                    : "Show fewer contributors"
                }
                className="rounded-full w-8 h-8 border-2 hover:border-primary duration-100 md:border-border border-primary"
              >
                {collapsed ? `${extra}+` : "−"}
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              {collapsed ? (
                <>
                  {extra} <GitCommit />
                </>
              ) : (
                "Show fewer"
              )}
            </TooltipContent>
          </Tooltip>
        )}
      </section>
    </div>
  );
}
