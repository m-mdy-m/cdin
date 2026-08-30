import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { DownloadIcon } from "lucide-react";

export default function MacOsInstallationMethod() {
  return (
    <div className="grid grid-cols-6 gap-2">
      <div className="col-span-6 lg:col-span-2">
        <h6 className="flex mb-1 items-center gap-1 text-xl">
          <img
            src="/os-icons/macos.svg"
            alt="macos"
            className="w-5 aspect-square dark:invert"
          />{" "}
          macOS <sub className="text-sm text-muted-foreground">(arm64)</sub>
        </h6>
        <Button
          asChild
          variant="default"
          className="w-full items-center lg:text-sm flex flex-row py-6 font-semibold"
        >
          <a href="https://github.com/m-mdy-m/cdin/releases/download/v0.1.0-beta.6/cdin-v0.1.0-beta.6-macos.dmg">
            <DownloadIcon /> Download for macOS
          </a>
        </Button>
      </div>
      <Card className="col-span-6 lg:col-span-4 text-xs p-4 gap-0 min-h-0 h-fit overflow-x-auto">
        <pre className="font-mono leading-relaxed whitespace-pre-wrap">
          <span className="block text-muted-foreground">
            // Download cdin-v0.1.0-beta.6-macos.dmg and double-click it.
          </span>
          <span className="block text-muted-foreground">
            // Drag cdin into the Applications folder shortcut.
          </span>
          <span className="block text-muted-foreground">
            // Eject the disk image and open cdin from Launchpad or Spotlight.
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            // SDL3 is bundled inside the .app — no Homebrew or extra installs
            needed.
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # Updating &amp; Uninstalling
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">update</span>
            <span className="text-muted-foreground">
              {" "}
              # update to latest release
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">update</span>{" "}
            <span className="text-chart-4">--check</span>
            <span className="text-muted-foreground">
              {" "}
              # just check, don't install
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">update</span>{" "}
            <span className="text-chart-4">--version</span>{" "}
            <span className="text-chart-3">0.2.0</span>
          </span>
          <span className="block"> </span>
          <span className="block">
            <span className="text-chart-5">python3</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">uninstall</span>
            <span className="text-muted-foreground">
              {" "}
              # remove installed files
            </span>
          </span>
        </pre>
      </Card>
    </div>
  );
}
