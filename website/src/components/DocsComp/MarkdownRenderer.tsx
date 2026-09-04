import { Link } from "react-router";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { docs } from "@/lib/docs";

const DOC_SLUGS = new Set(docs.map((d) => d.slug));

function isInternalDoc(href: string): boolean {
  if (!href.endsWith(".md")) return false;
  const slug = href.split("/").pop()!.replace(/\.md$/, "");
  return DOC_SLUGS.has(slug);
}

function docSlugFromHref(href: string): string {
  return href.split("/").pop()!.replace(/\.md$/, "");
}

function MarkdownLink({
  href,
  children,
  ...props
}: React.AnchorHTMLAttributes<HTMLAnchorElement>) {
  if (href && isInternalDoc(href)) {
    return (
      <Link to={`/docs/${docSlugFromHref(href)}`} {...props}>
        {children}
      </Link>
    );
  }

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      {...props}
    >
      {children}
    </a>
  );
}

export default function MarkdownRenderer({ content }: { content: string }) {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      components={{
        a: MarkdownLink,
        h1: ({ children, ...props }) => (
          <h1
            className="text-3xl font-bold mt-10 mb-6 pb-2 border-b"
            {...props}
          >
            {children}
          </h1>
        ),
        h2: ({ children, ...props }) => (
          <h2
            className="text-2xl font-semibold mt-8 mb-4"
            id={String(children)
              .toLowerCase()
              .replace(/[^a-z0-9]+/g, "-")
              .replace(/(^-|-$)/g, "")}
            {...props}
          >
            {children}
          </h2>
        ),
        h3: ({ children, ...props }) => (
          <h3 className="text-xl font-semibold mt-6 mb-3" {...props}>
            {children}
          </h3>
        ),
        p: ({ children, ...props }) => (
          <p className="text-muted-foreground leading-relaxed mb-4" {...props}>
            {children}
          </p>
        ),
        ul: ({ children, ...props }) => (
          <ul className="list-disc list-inside mb-4 space-y-1 text-muted-foreground" {...props}>
            {children}
          </ul>
        ),
        ol: ({ children, ...props }) => (
          <ol className="list-decimal list-inside mb-4 space-y-1 text-muted-foreground" {...props}>
            {children}
          </ol>
        ),
        li: ({ children, ...props }) => (
          <li className="text-muted-foreground" {...props}>
            {children}
          </li>
        ),
        code: ({ className, children, ...props }) => {
          const isBlock = className?.includes("language-");
          if (isBlock) {
            return (
              <code
                className="block bg-muted rounded-md p-4 my-4 text-sm overflow-x-auto font-mono"
                {...props}
              >
                {children}
              </code>
            );
          }
          return (
            <code
              className="bg-muted px-1.5 py-0.5 rounded text-sm font-mono"
              {...props}
            >
              {children}
            </code>
          );
        },
        pre: ({ children, ...props }) => (
          <pre
            className="bg-muted rounded-md p-4 my-4 text-sm overflow-x-auto font-mono"
            {...props}
          >
            {children}
          </pre>
        ),
        blockquote: ({ children, ...props }) => (
          <blockquote
            className="border-l-4 border-primary pl-4 my-4 text-muted-foreground italic"
            {...props}
          >
            {children}
          </blockquote>
        ),
        table: ({ children, ...props }) => (
          <div className="overflow-x-auto my-4">
            <table className="w-full text-sm text-left" {...props}>
              {children}
            </table>
          </div>
        ),
        thead: ({ children, ...props }) => (
          <thead className="border-b font-semibold" {...props}>
            {children}
          </thead>
        ),
        tbody: ({ children, ...props }) => (
          <tbody className="divide-y" {...props}>
            {children}
          </tbody>
        ),
        tr: ({ children, ...props }) => (
          <tr className="border-b last:border-0" {...props}>
            {children}
          </tr>
        ),
        th: ({ children, ...props }) => (
          <th className="px-4 py-2 font-semibold" {...props}>
            {children}
          </th>
        ),
        td: ({ children, ...props }) => (
          <td className="px-4 py-2 text-muted-foreground" {...props}>
            {children}
          </td>
        ),
        hr: (props) => <hr className="my-8 border-border" {...props} />,
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
