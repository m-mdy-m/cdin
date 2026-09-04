import { useParams } from "react-router";
import { getDocBySlug } from "@/lib/docs";
import MarkdownRenderer from "@/components/DocsComp/MarkdownRenderer";
import NotFound from "@/components/NotFound";
import ShortCuts from "./ShortCuts";

export default function DocView() {
  const { slug } = useParams<{ slug: string }>();
  const doc = getDocBySlug(slug!);

  if (!doc) {
    return <NotFound />;
  }

  return (
    <article className="px-8 py-10 h-full gap-4 grid grid-cols-9">
      <div className="col-span-6">
        <MarkdownRenderer content={doc.content} />
      </div>
      <div className="col-span-3 relative">
        <ShortCuts />
      </div>
    </article>
  );
}
