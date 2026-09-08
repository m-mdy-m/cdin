import { docsFooterLinks } from "@/consts/docsFooterLinks";
import { Button } from "../ui/button";
import { Link } from "react-router";

export default function DocsFooter() {
  return (
    <footer className="border-t border-dashed py-6 mt-9">
      <div className="flex flex-wrap items-center justify-center gap-4">
        {docsFooterLinks.map((link, i) => (
          <Button
            key={i}
            className="px-0 underline opacity-80 hover:opacity-100"
            asChild
            variant="link"
            size="xs"
          >
            <Link to={link.href} target={link.external ? "_blank" : "_self"}>
              {link.label}
            </Link>
          </Button>
        ))}
      </div>
    </footer>
  );
}
