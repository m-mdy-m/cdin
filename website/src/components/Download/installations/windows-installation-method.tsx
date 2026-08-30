import { DownloadIcon } from "lucide-react";
import { Button } from "../../ui/button";
import { Card } from "../../ui/card";

export default function WindowsInstallationMethod() {
  return (
    <div className="grid grid-cols-6 gap-2">
      <div className="col-span-6 lg:col-span-2">
        <h6 className="flex mb-1 items-center gap-1 text-xl">
          <img
            src="/os-icons/windows.svg"
            alt="windows"
            className="w-5 aspect-square dark:invert"
          />{" "}
          Windows <sub className="text-sm text-muted-foreground">(x86_64)</sub>
        </h6>
        <Button
          asChild
          variant="default"
          className="w-full items-center lg:text-sm flex flex-row py-6 font-semibold"
        >
          <a href="https://github.com/m-mdy-m/cdin/releases/download/v0.1.0-beta.6/cdin-v0.1.0-beta.6-windows-x86_64.zip">
            <DownloadIcon /> Download for windows
          </a>
        </Button>
      </div>
      <Card className="col-span-6 lg:col-span-4 text-xs p-4 gap-0 overflow-x-auto h-fit min-h-0">
        <pre className="font-mono leading-relaxed whitespace-pre-wrap">
          <span className="block text-muted-foreground">
            // Download cdin-v0.1.0-beta.6-windows-x86_64.zip and extract it.
          </span>
          <span className="block text-muted-foreground">
            // Open PowerShell or Command Prompt inside the extracted folder and
            run:
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # Interactive (recommended):
          </span>
          <span className="block">
            <span className="text-chart-5">python</span>{" "}
            <span className="text-chart-5">cdin.py</span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            # Or non-interactive:
          </span>
          <span className="block">
            <span className="text-chart-5">python</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>
          </span>
          <span className="block">
            <span className="text-chart-5">python</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>{" "}
            <span className="text-chart-4">--shortcut</span>
            <span className="text-muted-foreground">
              {" "}
              # also create desktop shortcut
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>{" "}
            <span className="text-chart-4">--register-filetypes</span>
            <span className="text-muted-foreground">
              {" "}
              # set as default for text/code files
            </span>
          </span>
          <span className="block">
            <span className="text-chart-5">python</span>{" "}
            <span className="text-chart-5">cdin.py</span>{" "}
            <span className="text-primary">install</span>{" "}
            <span className="text-chart-4">--prefix</span>{" "}
            <span className="text-chart-3">C:\Tools\cdin</span>
            <span className="text-muted-foreground">
              {" "}
              # custom install location
            </span>
          </span>
          <span className="block"> </span>
          <span className="block text-muted-foreground">
            // cdin.exe, SDL3.dll, and the Lua DLL are added to
            %LOCALAPPDATA%\cdin\bin
          </span>
          <span className="block text-muted-foreground">
            // and that folder is added to your user PATH automatically.
          </span>
        </pre>
      </Card>
    </div>
  );
}
