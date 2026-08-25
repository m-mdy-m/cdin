import BottomBar from "@/components/BottomBartion/BottomBar";
import Navbar from "@/components/Navigations/Navbar";
import { Outlet } from "react-router";

export default function Layout() {
  return (
    <div
      id="fira-code-mono"
      className="max-w-7xl min-h-svh grid grid-cols-1 grid-rows-[auto_1fr_auto] overflow-x-hidden border-x mx-auto"
    >
      <Navbar />
      <Outlet />
      <BottomBar />
    </div>
  );
}
