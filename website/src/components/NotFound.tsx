import { Link } from "react-router";
import logo from "../../../scripts/icon.svg";

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center md:my-0 px-4 my-32">
      <div className="text-center flex flex-col items-center border w-full md:w-fit">
        <img
          src={logo}
          alt="logo"
          className="md:w-32 w-20 text-center aspect-square"
        />
        <h1 className="font-semibold lg:text-xl md:px-20 lg:px-32">
          404 - PAGE NOT FOUND
        </h1>
        <div className="grid grid-cols-2 mt-2 border-t w-full">
          <Link
            to={`/`}
            className="border-r hover:bg-foreground/10 py-6 underline"
          >
            HOME
          </Link>
          <button
            onClick={() => window.history.back()}
            className="border-r hover:bg-foreground/10 py-6 underline cursor-pointer"
          >
            BACK
          </button>
        </div>
      </div>
    </div>
  );
}
