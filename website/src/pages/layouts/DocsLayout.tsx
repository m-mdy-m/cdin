import { Outlet } from "react-router";
import { ThemeProvider } from "@/components/ThemeProvider";
import DocsHeader from "@/components/DocsComp/Header";
import Sidebar from "@/components/DocsComp/Sidebar";

export default function DocsLayout() {
  return (
    <>
      <ThemeProvider defaultTheme="dark" storageKey="vite-ui-theme">
        <div className="fira-code-mono relative grid grid-rows-[auto_1fr] w-full h-screen overflow-hidden">
          <DocsHeader />
          <div className="grid grid-cols-[auto_1fr] overflow-y-scroll">
            <Sidebar />
            <Outlet />
          </div>
        </div>
      </ThemeProvider>
    </>
  );
}
