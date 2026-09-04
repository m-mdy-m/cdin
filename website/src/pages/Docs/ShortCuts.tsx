import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { Heading } from "@/lib/docs";

function scrollToHeading(id: string) {
  const el = document.getElementById(id);
  if (el) {
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

export default function ShortCuts({ headings }: { headings: Heading[] }) {
  if (headings.length === 0) return null;

  return (
    <Card className="sticky top-4 hidden md:block">
      <CardHeader>
        <CardTitle className="text-sm font-semibold">On this page</CardTitle>
      </CardHeader>
      <CardContent>
        <nav className="space-y-1">
          {headings.map((heading) => (
            <button
              key={heading.id}
              onClick={() => scrollToHeading(heading.id)}
              className="block w-full text-left text-sm text-muted-foreground hover:text-foreground transition-colors px-2 py-1 rounded hover:bg-accent/50 cursor-pointer"
            >
              {heading.title}
            </button>
          ))}
        </nav>
      </CardContent>
    </Card>
  );
}
