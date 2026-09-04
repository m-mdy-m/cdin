import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogTrigger,
} from "@/components/ui/dialog";
import { FileText, SearchIcon, XIcon } from "lucide-react";
import {
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
} from "@/components/ui/input-group";
import { Button } from "../ui/button";
import { useState } from "react";
import { useNavigate } from "react-router";
import { docs } from "@/lib/docs";

export default function SearchDocs() {
  const [query, setQuery] = useState("");
  const navigate = useNavigate();

  const results = query.trim()
    ? docs
        .filter(
          (d) =>
            d.title.toLowerCase().includes(query.toLowerCase()) ||
            d.slug.toLowerCase().includes(query.toLowerCase()) ||
            d.content.toLowerCase().includes(query.toLowerCase()),
        )
        .slice(0, 8)
    : [];

  const grouped = results.reduce<Record<string, typeof results>>((acc, doc) => {
    (acc[doc.category] ??= []).push(doc);
    return acc;
  }, {});

  function goTo(slug: string) {
    navigate(`/docs/${slug}`);
    setQuery("");
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button
          size="lg"
          variant="ghost"
          className="lg:text-lg border border-accent/50 hover:border-accent font-normal h-fit p-0"
        >
          <div className="min-w-0 flex items-center px-4 gap-2 text-muted-foreground w-fit rounded py-2">
            <SearchIcon />
            Search docs...
          </div>
        </Button>
      </DialogTrigger>
      <DialogContent
        showCloseButton={false}
        className="duration-100 transition-all h-fit"
      >
        <InputGroup className="h-12 border-border border-2">
          <InputGroupInput
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search docs..."
          />
          <InputGroupAddon>
            <SearchIcon />
          </InputGroupAddon>
          {query.length === 0 ? null : (
            <InputGroupAddon className="" align="inline-end">
              <Button size="icon" variant="ghost" onClick={() => setQuery("")}>
                <XIcon />
              </Button>
            </InputGroupAddon>
          )}
        </InputGroup>

        <section>
          {query.trim() && (
            <div className="max-h-80 overflow-y-auto grid grid-cols-1 gap-2">
              {results.length > 0 ? (
                <div className="font-semibold">
                  {results.length} results for "{query}"
                </div>
              ) : null}
              {results.length === 0 ? (
                <p className="text-muted-foreground text-sm p-2">
                  No results found.
                </p>
              ) : (
                Object.entries(grouped).map(([category, items]) => (
                  <div key={category}>
                    <div className="flex items-center gap-2 px-2 py-1">
                      <FileText size={16} />
                      <h2 className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
                        {category} ({items.length})
                      </h2>
                    </div>
                    {items.map((doc) => (
                      <DialogClose asChild key={doc.slug}>
                        <Button
                          onClick={() => goTo(doc.slug)}
                          className="w-full text-left px-4 py-2 h-fit  justify-start"
                          variant="ghost"
                        >
                          {doc.title}
                        </Button>
                      </DialogClose>
                    ))}
                  </div>
                ))
              )}
            </div>
          )}
        </section>
      </DialogContent>
    </Dialog>
  );
}
