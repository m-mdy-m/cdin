import { Link } from "react-router";
import logo from "../../../../scripts/icon.svg";
import { ModeToggle } from "../ModeToggle";
import { Button } from "../ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { SearchIcon } from "lucide-react";
import {
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupInput,
  InputGroupText,
  InputGroupTextarea,
} from "@/components/ui/input-group";
import MobileView from "../Navigations/MobileView";

export default function DocsHeader() {
  return (
    <header className="flex boder-b items-center justify-between pl-2 pr-6 py-4 sticky top-0">
      <Link to={`/`}>
        <img src={logo} alt="logo.svg" className="w-14 md:w-16 aspect-square" />
      </Link>
      <MobileView />
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
        <Dialog>
          <DialogTrigger asChild>
            <Button
              size="lg"
              variant="ghost"
              className="lg:text-lg border border-accent/50 hover:border-accent font-normal h-fit p-0"
            >
              <div className="min-w-0 flex items-center px-4 gap-2 text-muted-foreground w-fit rounded py-2">
                <SearchIcon />
                Search docs...
              </div>
            </Button>
          </DialogTrigger>
          <DialogContent showCloseButton={false}>
            <InputGroup>
              <InputGroupInput placeholder="Search..." />
              <InputGroupAddon>
                <SearchIcon />
              </InputGroupAddon>
            </InputGroup>
          </DialogContent>
        </Dialog>
      </section>
    </header>
  );
}
