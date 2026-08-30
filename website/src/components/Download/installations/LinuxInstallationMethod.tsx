import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { DownloadIcon } from "lucide-react";

export default function LinuxInstallationMethod() {
  return (
    <div className="grid grid-cols-6 gap-2">
      <div className="col-span-6 lg:col-span-2">
        <h6 className="flex mb-1 items-center gap-1 text-xl">
          <img
            src="/os-icons/linux.svg"
            alt="linux"
            className="w-5 aspect-square dark:invert"
          />{" "}
          Linux <sub className="text-sm text-muted-foreground">(x86_64)</sub>
        </h6>
        <Button
          asChild
          variant="default"
          className="w-full items-center lg:text-sm flex flex-row py-6 font-semibold"
        >
          <a href="https://github.com/m-mdy-m/cdin/releases/download/v0.1.0-beta.6/cdin-v0.1.0-beta.6-linux-x86_64.tar.gz">
            <DownloadIcon /> Download for linux
          </a>
        </Button>
      </div>
      <Card className="col-span-6 lg:col-span-4 text-xs p-4 gap-0">
        <p className="fira-code-mono leading-relaxed whitespace-pre-wrap">
          <span className="block text-muted-foreground">
            // Requires Python 3.8+ — comes pre-installed on all supported
            platforms.
          </span>
          <span className="block"> </span>
          <span className="block">
            <span className="text-chart-5">tar</span>{" "}
            <span className="text-chart-4">xzf</span>{" "}
            <span className="text-chart-3">
              cdin-v0.1.0-beta.6-linux-x86_64.tar.gz
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">cd</span>{" "}
            <span className="text-chart-3">
              cdin-v0.1.0-beta.6-linux-x86_64
            </span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # Interactive (recommended for first-time install):
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # Or non-interactive:
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>
            <span className="text-muted-foreground">
              {" "}
              # → ~/.local (no sudo)
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>{" "}
            <span className="text-chart-4">--prefix</span>{" "}
            <span className="text-chart-3">/usr/local</span>
            <span className="text-muted-foreground">
              {" "}
              # system-wide (needs sudo)
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>{" "}
            <span className="text-chart-4">--shortcut</span>
            <span className="text-muted-foreground">
              {" "}
              # also create .desktop entry
            </span>
          </span>
        </p>
        <p className="fira-code-mono text-muted-foreground leading-relaxed">
          // SDL3 runtime — needed at runtime if not already installed:
        </p>
        <p className="fira-code-mono leading-relaxed">
          <span className="text-muted-foreground">Ubuntu 24.04+:</span>{" "}
          <span className="text-chart-5">sudo</span>{" "}
          <span className="text-primary">apt</span>{" "}
          <span className="text-primary">install</span>{" "}
          <span className="text-chart-3">libsdl3-0</span>
        </p>
        <p className="fira-code-mono leading-relaxed">
          <span className="text-muted-foreground">Other distros: see </span>
          <Button asChild variant="link" className="p-0 underline h-fit w-fit">
            <a
              target="_blank"
              href="https://github.com/libsdl-org/SDL/releases"
            >
              SDL3 releases
            </a>
          </Button>
        </p>
      </Card>
    </div>
  );
}
