import { useParams } from "react-router";
import { getDocBySlug } from "@/lib/docs";
import MarkdownRenderer from "@/components/DocsComp/MarkdownRenderer";
import NotFound from "@/components/NotFound";

export default function DocView() {
  const { slug } = useParams<{ slug: string }>();
  const doc = getDocBySlug(slug!);

  if (!doc) {
    return <NotFound />;
  }

  return (
    <article className="px-8 py-10 overflow-y-auto h-full">
      <MarkdownRenderer content={doc.content} />
    </article>
  );
}
