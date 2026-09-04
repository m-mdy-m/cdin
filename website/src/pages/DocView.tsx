import { useEffect } from "react";
import { useParams, useLocation } from "react-router";
import { getDocBySlug, getHeadings } from "@/lib/docs";
import MarkdownRenderer from "@/components/DocsComp/MarkdownRenderer";
import NotFound from "@/components/NotFound";
import ShortCuts from "./ShortCuts";

export default function DocView() {
  const { slug } = useParams<{ slug: string }>();
  const location = useLocation();
  const doc = getDocBySlug(slug!);

  useEffect(() => {
    const container = document.querySelector(".overflow-y-scroll");
    if (container) container.scrollTop = 0;
  }, [slug]);

  useEffect(() => {
    if (location.hash) {
      const id = location.hash.slice(1);
      const el = document.getElementById(id);
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    }
  }, [slug, location.hash]);

  if (!doc) {
    return <NotFound />;
  }

  const headings = getHeadings(doc.content);

  return (
    <article className="px-4 md:px-8 py-0 h-full gap-4 grid grid-cols-9">
      <div className="col-span-6">
        <MarkdownRenderer content={doc.content} />
      </div>
      <div className="col-span-3">
        <ShortCuts headings={headings} />
      </div>
    </article>
  );
}
