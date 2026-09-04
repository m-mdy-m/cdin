import { Link } from "react-router";
import { docs } from "@/lib/docs";

const CATEGORY_LABELS: Record<string, string> = {
  guides: "Guides",
  architecture: "Architecture",
};

export default function DocsPage() {
  const grouped = docs.reduce<Record<string, typeof docs>>((acc, doc) => {
    (acc[doc.category] ??= []).push(doc);
    return acc;
  }, {});

  return (
    <div className="px-8 py-10 overflow-y-auto h-full">
      <h1 className="text-3xl font-bold mb-2">Documentation</h1>
      <p className="text-muted-foreground mb-8">
        Everything you need to get started with cdin.
      </p>

      <div className="space-y-8">
        {Object.entries(grouped).map(([category, items]) => (
          <div key={category}>
            <h2 className="text-xl font-semibold mb-3">
              {CATEGORY_LABELS[category] ?? category}
            </h2>
            <ul className="space-y-2">
              {items.map((doc) => (
                <li key={doc.slug}>
                  <Link
                    to={`/docs/${doc.slug}`}
                    className="block px-4 py-3 rounded-md border hover:bg-accent/50 transition-colors"
                  >
                    <span className="font-medium">{doc.title}</span>
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}
