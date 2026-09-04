const modules = import.meta.glob<string>(
  "../../../docs/**/*.md",
  { query: "?raw", import: "default", eager: true },
);

export interface Doc {
  slug: string;
  category: string;
  title: string;
  content: string;
}

function slugFromPath(path: string): string {
  const parts = path.split("/");
  return parts[parts.length - 1].replace(/\.md$/, "");
}

function categoryFromPath(path: string): string {
  const parts = path.split("/");
  const docsIdx = parts.indexOf("docs");
  return parts[docsIdx + 1] ?? "misc";
}

function titleFromContent(raw: string): string {
  const match = raw.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : "Untitled";
}

export const docs: Doc[] = Object.entries(modules)
  .map(([path, content]) => ({
    slug: slugFromPath(path),
    category: categoryFromPath(path),
    title: titleFromContent(content),
    content,
  }))
  .sort((a, b) => a.category.localeCompare(b.category) || a.title.localeCompare(b.title));

export function getDocBySlug(slug: string): Doc | undefined {
  return docs.find((d) => d.slug === slug);
}

export function headingToId(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

export interface Heading {
  title: string;
  id: string;
}

export function getHeadings(content: string): Heading[] {
  const headings: Heading[] = [];
  const regex = /^##\s+(.+)$/gm;
  let match;
  while ((match = regex.exec(content)) !== null) {
    const title = match[1].replace(/`/g, "").trim();
    headings.push({ title, id: headingToId(title) });
  }
  return headings;
}
