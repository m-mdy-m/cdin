import { Outlet } from "react-router";
import { ThemeProvider } from "@/components/ThemeProvider";
import DocsHeader from "@/components/DocsComp/Header";
import Sidebar from "@/components/DocsComp/Sidebar";

export default function DocsLayout() {
  return (
    <>
      <ThemeProvider defaultTheme="dark" storageKey="vite-ui-theme">
        <div className="fira-code-mono relative grid grid-rows-[auto_1fr] min-h-screen w-full overflow-x-hidden">
          <DocsHeader />
          <div className="grid grid-cols-[auto_1fr]">
            <Sidebar />
            <Outlet />
          </div>
        </div>
      </ThemeProvider>
    </>
  );
}
