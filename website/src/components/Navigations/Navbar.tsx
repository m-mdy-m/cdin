import logo from "../../../../scripts/icon.svg";
import MobileView from "./MobileView";
import DesktopView from "./DesktopView";

export default function Navbar() {
  return (
    <nav className="md:pl-2 pl-0 pr-4 md:pr-8 py-2 lg:py-6 flex items-center border-b bg-background sticky top-0 z-10 justify-between">
      <a href="/" className="flex items-center ">
        <img src={logo} alt="cdin_logo" className="w-16 aspect-square" />
      </a>
      <MobileView />
      <DesktopView />
    </nav>
  );
}
