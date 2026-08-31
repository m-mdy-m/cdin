import { navLinks } from "@/consts/navLinks";
import { ModeToggle } from "../ModeToggle";
import { Button } from "../ui/button";
import { Link } from "react-router";

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
            <Link to={link.href}>{link.label}</Link>
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
              <img
                src="/cdin/github.svg"
                alt="github logo"
                className="w-5 invert"
              />
              {link.label}
            </a>
          </Button>
        ))}
    </div>
  );
}
