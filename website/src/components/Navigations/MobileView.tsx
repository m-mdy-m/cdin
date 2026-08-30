import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import { Menu } from "lucide-react";
import { Button } from "../ui/button";
import { ModeToggle } from "../ModeToggle";
import { navLinks } from "@/consts/navLinks";

export default function MobileView() {
  return (
    <div className="md:hidden flex  ">
      <Sheet>
        <SheetTrigger asChild>
          <Button size={"icon-lg"} variant={"outline"}>
            <Menu />
          </Button>
        </SheetTrigger>
        <SheetContent>
          <SheetHeader className="border-b">
            <SheetTitle className="w-fit">
              <a
                href="/"
                className="flex items-center font-semibold text-3xl font-mono"
              >
                cdin
              </a>
            </SheetTitle>
            <SheetDescription className=" fira-code-mono tracking-tighter ">
              trust me. it's worth it.
            </SheetDescription>
          </SheetHeader>
          <div className="flex flex-col items-start fira-code-mono">
            {navLinks
              .filter((link) => !link.external)
              .map((link) => (
                <Button
                  className="rounded-none py-6 w-full text-xl flex flex-col items-start"
                  size={"lg"}
                  key={link.label}
                  variant={"ghost"}
                  asChild
                >
                  <a href={link.href}>{link.label}</a>
                </Button>
              ))}
          </div>
          <SheetFooter className="flex flex-row">
            <ModeToggle />
            <Button
              className="h-fit py-2 lg:text-lg font-normal flex flex-1 items-center"
              size={"lg"}
              variant="default"
              asChild
            >
              <a
                href={`https://github.com/m-mdy-m/cdin`}
                target="_blank"
                rel="noopener noreferrer"
              >
                <img
                  src="/github.svg"
                  alt="github logo"
                  className="w-5 invert"
                />
                GitHub
              </a>
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </div>
  );
}
