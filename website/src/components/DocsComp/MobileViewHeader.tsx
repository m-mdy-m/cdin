import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Menu } from "lucide-react";
import { Button } from "../ui/button";
import { ModeToggle } from "../ModeToggle";
import { Link } from "react-router";
import SearchDocs from "./SearchDocs";
import { docs } from "@/lib/docs";

const CATEGORY_LABELS: Record<string, string> = {
  guides: "Guides",
  architecture: "Architecture",
};

export default function MobileViewHeader() {
  const grouped = docs.reduce<Record<string, typeof docs>>((acc, doc) => {
    (acc[doc.category] ??= []).push(doc);
    return acc;
  }, {});

  return (
    <div className="md:hidden flex">
      <Sheet>
        <SheetTrigger asChild>
          <Button size="icon-lg" variant="outline">
            <Menu />
          </Button>
        </SheetTrigger>
        <SheetContent className="">
          <SheetHeader className="border-b">
            <SheetTitle className="w-fit">
              <Link
                to="/"
                className="flex items-center font-semibold text-3xl font-mono"
              >
                cdin
              </Link>
            </SheetTitle>
            <SheetDescription className="fira-code-mono tracking-tighter">
              trust me. it's worth it.
            </SheetDescription>
          </SheetHeader>

          <div className="px-4 py-2 w-full">
            <SearchDocs className="w-full" />
          </div>

          <nav className="px-4 space-y-6 overflow-y-auto fira-code-mono">
            {Object.entries(grouped).map(([category, items]) => (
              <div key={category}>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-2">
                  {CATEGORY_LABELS[category] ?? category}
                </h3>
                <ul className="space-y-0.5">
                  {items.map((doc) => (
                    <li key={doc.slug}>
                      <Button
                        className="rounded-none py-6 w-full text-lg flex flex-col items-start"
                        size="lg"
                        variant="ghost"
                        asChild
                      >
                        <Link to={`/docs/${doc.slug}`}>{doc.title}</Link>
                      </Button>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </nav>

          <SheetFooter className="flex flex-row px-4 items-center py-2">
            <ModeToggle />
            <Button className="flex-1" size="lg" variant="default" asChild>
              <Link to="/download">Download</Link>
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </div>
  );
}
