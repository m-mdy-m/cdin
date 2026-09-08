import BottomBar from "@/components/BottomBartion/BottomBar";
import Navbar from "@/components/Navigations/Navbar";
import { Outlet } from "react-router";
import { ThemeProvider } from "@/components/ThemeProvider";
import { TooltipProvider } from "@/components/ui/tooltip";

export default function Layout() {
  return (
    <div className="fira-code-mono relative max-w-5xl min-h-svh grid grid-cols-1 grid-rows-[auto_1fr_auto]  border-x mx-auto">
      <div className="h-px w-screen fixed top-0 left-0 right-0 z-50 bg-border" />
      <ThemeProvider defaultTheme="dark" storageKey="vite-ui-theme">
        <Navbar />

        <TooltipProvider>
          <Outlet />
        </TooltipProvider>
        <BottomBar />
      </ThemeProvider>
    </div>
  );
}
