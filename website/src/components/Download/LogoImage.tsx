import { Card, CardContent } from "../ui/card";
import logo from "../../../../scripts/icon.svg";

export default function LogoImage() {
  return (
    <div className="col-span-12 sm:col-span-3">
      <Card className="hover:border-primary duration-100 sm:w-full w-1/2 mx-auto">
        <CardContent>
          <img
            src={logo}
            alt="logo"
            className="object-cover w-full aspect-square"
          />
        </CardContent>
      </Card>
    </div>
  );
}
