import logo from "../../../../scripts/icon.svg";
import { Button } from "@/components/ui/button";
import { navLinks } from "@/consts/navLinks";
import { ModeToggle } from "@/components/mode-toggle";

export default function Navbar() {
  return (
    <nav className="pl-2 pr-8 py-6 flex items-center border-b bg-background sticky top-0 z-10 justify-between">
      <a href="/" className="flex items-center ">
        <img src={logo} alt="cdin_logo" className="w-16 aspect-square" />
        <span className="lg:text-lg -translate-x-2">cdin</span>
      </a>
      <div className="flex items-center gap-2">
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
              <a
                href={link.href}
                target="_blank"
                rel="noopener noreferrer"
              >
                <img
                  src="/github.svg"
                  alt="github logo"
                  className="w-5 invert"
                />
                {link.label}
              </a>
            </Button>
          ))}
      </div>
    </nav>
  );
}
