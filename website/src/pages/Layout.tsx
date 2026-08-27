import BottomBar from "@/components/BottomBartion/BottomBar";
import Navbar from "@/components/Navigations/Navbar";
import { Outlet } from "react-router";
import { ThemeProvider } from "@/components/theme-provider";

export default function Layout() {
  return (
    <div
      id="fira-code-mono"
      className="relative max-w-5xl min-h-svh grid grid-cols-1 grid-rows-[auto_1fr_auto]  border-x mx-auto"
    >
      <ThemeProvider defaultTheme="dark" storageKey="vite-ui-theme">
        <Navbar />
        <Outlet />
        <BottomBar />
      </ThemeProvider>
    </div>
  );
}
