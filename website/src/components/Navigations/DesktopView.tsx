import { navLinks } from "@/consts/navLinks";
import { ModeToggle } from "../mode-toggle";
import { Button } from "../ui/button";

export default function DesktopView() {
  return (
    <div className="md:flex hidden items-center gap-2">
      {navLinks
        .filter((link) => !link.external)
        .map((link) => (
          <Button
            className="h-fit py-2 lg:text-lg font-normal flex items-center"
            size={"lg"}
            key={link.href}
            variant="ghost"
            asChild
          >
            <a href={link.href}>{link.label}</a>
          </Button>
        ))}
      <ModeToggle />
      {navLinks
        .filter((link) => link.external)
        .map((link) => (
          <Button
            className="h-fit py-2 lg:text-lg font-normal flex items-center"
            size={"lg"}
            key={link.href}
            variant="default"
            asChild
          >
            <a href={link.href} target="_blank" rel="noopener noreferrer">
              <img src="/github.svg" alt="github logo" className="w-5 invert" />
              {link.label}
            </a>
          </Button>
        ))}
    </div>
  );
}
