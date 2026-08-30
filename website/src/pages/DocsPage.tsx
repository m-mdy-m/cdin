import { Construction } from "lucide-react";

export default function DocsPage() {
  return (
    <div className="flex  flex-col items-center justify-center gap-2 sm:h-auto min-h-[60vh]">
      <Construction className="size-8 text-muted-foreground animate-pulse sm:size-16" />
      <p className="text-muted-foreground">Docs — under development</p>
    </div>
  );
}
