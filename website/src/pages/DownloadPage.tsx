import { Button } from "@/components/ui/button";
import { ArrowRight } from "lucide-react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
import LogoImage from "@/components/Download/LogoImage";
import LinuxInstallationMethod from "@/components/Download/installations/LinuxInstallationMethod";
import WindowsInstallationMethod from "@/components/Download/installations/WindowsInstallationMethod";
import { Separator } from "@/components/ui/separator";
import MacOsInstallationMethod from "@/components/Download/installations/MacOsInstallationMethod";
import QuickStart from "@/components/Download/installations/QuickStart";

export default function DownloadPage() {
  return (
    <div className="lg:p-10 px-4 py-10">
      <div className="grid grid-cols-12 gap-6">
        <LogoImage />
        <div className="col-span-12 sm:col-span-9 flex flex-col">
          <h1 className="lg:text-2xl text-xl font-thin italic ">
            0.1.0-beta.6
          </h1>
          <span className="flex items-center justify-between mb-10">
            <h2>Jul 13, 2026</h2>
            <Button
              asChild
              variant="link"
              size="sm"
              className="px-0 duration-100 hover:gap-2 group"
            >
              <a
                href="https://github.com/m-mdy-m/cdin/blob/main/CHANGELOG.md"
                target="_blank"
              >
                View changelog{" "}
                <ArrowRight className="group-hover:-rotate-45 duration-100" />
              </a>
            </Button>
          </span>
          <Tabs defaultValue="stable" className="w-full min-w-0">
            <TabsList className="w-full mb-4 md:py-6">
              <TabsTrigger
                value="stable"
                className="md:py-5 md:text-xl cursor-pointer"
              >
                Stable
              </TabsTrigger>
              <TabsTrigger
                value="test"
                className="md:py-5 md:text-xl cursor-pointer"
              >
                Test
              </TabsTrigger>
            </TabsList>
            <TabsContent className="flex flex-col" value="stable">
              <LinuxInstallationMethod />

              <Separator className="my-10" />
              <WindowsInstallationMethod />
              <Separator className="my-10" />

              <MacOsInstallationMethod />
            </TabsContent>
            <TabsContent value="test">
              <QuickStart />
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </div>
  );
}
