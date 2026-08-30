import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";

export default function QuickStart() {
  return (
    <div className="flex flex-col gap-4">
      <h3 className="lg:text-2xl text-xl font-semibold">Quick start</h3>
      <Card className="text-xs p-4 gap-0 overflow-x-auto h-fit min-h-0">
        <pre className="leading-relaxed whitespace-pre-wrap">
          <span className="block">
            <span className="text-chart-5">git</span>{" "}
            <span className="text-primary">clone</span>{" "}
            <span className="text-chart-3">
              https://github.com/m-mdy-m/cdin.git
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">cd</span>{" "}
            <span className="text-chart-3">cdin</span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # build (requires gcc, make, SDL3, Lua 5.4)
          </span>
          <span className="block">
            <span className="text-chart-5">make</span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # run in the current directory
          </span>
          <span className="block">
            <span className="text-chart-5">./build/linux-release/cdin</span>{" "}
            <span className="text-chart-3">.</span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground"># or open a file</span>
          <span className="block">
            <span className="text-chart-5">./build/linux-release/cdin</span>{" "}
            <span className="text-chart-3">path/to/file.c</span>
          </span>
        </pre>
        <pre className="text-muted-foreground mt-4 leading-relaxed whitespace-pre-wrap">
          <span className="block">
            # see{" "}
            <Button
              asChild
              variant="link"
              className="p-0 underline h-fit w-fit"
            >
              <a
                target="_blank"
                href="https://github.com/m-mdy-m/cdin/blob/main/docs/guides/building.md"
              >
                Building from Source
              </a>
            </Button>{" "}
            for dependencies and platform-specific notes. There's also a Python
            script if you prefer not to use make directly:
          </span>
        </pre>
        <pre className="leading-relaxed whitespace-pre-wrap">
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">scripts/cdin.py</span>{" "}
            <span className="text-primary">build-install</span>
          </span>
        </pre>
      </Card>
    </div>
  );
}
