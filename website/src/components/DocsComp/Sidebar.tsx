import { Link, useLocation } from "react-router";
import { docs } from "@/lib/docs";

const CATEGORY_LABELS: Record<string, string> = {
  guides: "Guides",
  architecture: "Architecture",
};

export default function Sidebar() {
  const location = useLocation();

  const grouped = docs.reduce<Record<string, typeof docs>>((acc, doc) => {
    (acc[doc.category] ??= []).push(doc);
    return acc;
  }, {});

  return (
    <aside className="border-r p-4 md:block hidden">
      <nav className="space-y-6 sticky top-4 self-start">
        {Object.entries(grouped).map(([category, items]) => (
          <div key={category}>
            <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground mb-2">
              {CATEGORY_LABELS[category] ?? category}
            </h3>
            <ul className="space-y-1">
              {items.map((doc) => {
                const href = `/docs/${doc.slug}`;
                const active = location.pathname === href;
                return (
                  <li key={doc.slug}>
                    <Link
                      to={href}
                      className={`block px-2 py-1.5 rounded text-sm transition-colors ${
                        active
                          ? "bg-accent text-accent-foreground font-medium"
                          : "text-muted-foreground hover:bg-accent/50 hover:text-foreground"
                      }`}
                    >
                      {doc.title}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
    </aside>
  );
}
