import { CodeXmlIcon, Download } from "lucide-react";
import { Button } from "../ui/button";

export default function Hero() {
  return (
    <div className="px-4 py-10 md:px-10 md:py-16 flex flex-col items-center">
      <h1 className="text-2xl md:text-3xl lg:text-4xl font-semibold text-center">
        Vim-like lightweight text editor
      </h1>
      <p className="mt-4 mb-6 md:mt-6 md:mb-8 text-sm md:text-base text-muted-foreground text-center max-w-xl">
        A blazing-fast, keyboard-driven text editor with built-in Vim-style
        modal editing, powered by a minimal C core and fully customizable
        through readable Lua.
      </p>
      <div className="flex flex-col sm:flex-row items-center gap-3">
        <Button
          asChild
          variant={"default"}
          className="flex flex-row w-fit items-center text-white gap-2 py-4 md:py-6 text-base md:text-xl font-semibold"
          size={"lg"}
        >
          <a href="download">
            <Download className="size-5 md:size-6" />
            Download
          </a>
        </Button>
        <Button
          asChild
          variant={"secondary"}
          className="flex flex-row w-fit items-center dark:bg-accent/20 dark:hover:bg-accent/25 gap-2 py-4 md:py-6 text-base md:text-xl font-semibold"
          size={"lg"}
        >
          <a href="https://github.com/m-mdy-m/cdin" target="_blank">
            <CodeXmlIcon className="size-5 md:size-6" />
            Source
          </a>
        </Button>
      </div>
    </div>
  );
}
