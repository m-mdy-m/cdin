import { Button } from "@/components/ui/button";
import { useTheme } from "@/components/ThemeProvider";

export function ModeToggle() {
  const { setTheme, theme } = useTheme();

  return (
    <Button
      onClick={() => {
        if (theme === "light") {
          setTheme("dark");
        } else {
          setTheme("light");
        }
      }}
      className="h-fit py-2 lg:text-lg font-normal flex items-center"
      size={"lg"}
      variant={"ghost"}
    >
      Toggle
    </Button>
  );
}
