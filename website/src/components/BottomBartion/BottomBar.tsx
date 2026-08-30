import { footerLinks } from "@/consts/footerLinks";
import { Button } from "../ui/button";

export default function BottomBar() {
  return (
    <footer className="">
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 border-y">
        {footerLinks.map((link) => (
          <a
            key={link.label}
            className="py-10 text-center not-last:border-b sm:not-last:border-b-0 md:border-r-0 md:not-last:border-r m-0 rounded-none hover:bg-foreground/10 duration-100"
            href={link.href}
            target={link.external ? "_blank" : "_self"}
          >
            {link.label}{" "}
            <span className="text-muted-foreground opacity-80">
              {link.label === "GitHub" ? "[22]" : null}
            </span>
          </a>
        ))}
      </div>
      <div className="py-28">
        <p className="text-center w-full">
          MIT License Copyright (c) 2026{" "}
          <Button
            asChild
            className="px-0 font-semibold text-lg"
            variant={"link"}
          >
            <a target="_blank" href="https://github.com/m-mdy-m">
              m-mdy-m
            </a>
          </Button>
        </p>
      </div>
    </footer>
  );
}
