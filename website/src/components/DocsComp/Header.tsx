import { Link } from "react-router";
import logo from "../../../../scripts/icon.svg";
import { ModeToggle } from "../ModeToggle";
import { Button } from "../ui/button";
import SearchDocs from "./SearchDocs";
import MobileViewHeader from "./MobileViewHeader";

export default function DocsHeader() {
  return (
    <header className="flex border-b items-center justify-between pl-2 pr-6 py-4 ">
      <Link to={`/`}>
        <img src={logo} alt="logo.svg" className="w-14 md:w-16 aspect-square" />
      </Link>
      <MobileViewHeader />
      <section className="md:flex items-center gap-4 hidden">
        <div className="flex items-center">
          <ModeToggle />
          <Button
            asChild
            className="h-fit py-2 lg:text-lg font-normal flex items-center"
            size={"lg"}
            variant={"ghost"}
          >
            <Link to={`/download`}>Download</Link>
          </Button>
        </div>
        <SearchDocs className="w-fit" />
      </section>
    </header>
  );
}
