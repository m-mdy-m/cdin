export default function Philosophy() {
  return (
    <div className="mt-14 border-t py-10 px-4 md:p-10">
      <h1 className="lg:text-2xl font-semibold">What is our philosophy?</h1>

      <div className="mt-8 flex flex-col gap-4">
        <p className="text-muted-foreground lg:text-base text-sm">
          <span className="font-semibold text-foreground text-base">
            [<span className="text-primary relative -top-px">*</span>]
          </span>{" "}
          The codebase is meant to be readable. You should be able to find the
          edit loop, understand what it does, and change it. Functions are
          short. Modules are small. There are no clever abstractions that
          require you to know the whole project before touching any of it.
        </p>

        <p className="text-muted-foreground lg:text-base text-sm">
          <span className="font-semibold text-foreground text-base">
            [<span className="text-primary relative -top-px">*</span>]
          </span>{" "}
          Features belong in plugins. The core does the minimum that every
          editor needs. Anything optional is in data/plugins/ where it can be
          read, copied, modified, or replaced without touching the core. This is
          how lite-xl approaches things too, and it works.
        </p>

        <p className="text-muted-foreground lg:text-base text-sm">
          <span className="font-semibold text-foreground text-base">
            [<span className="text-primary relative -top-px">*</span>]
          </span>{" "}
          Startup time and memory use matter. The renderer only redraws what
          actually changed. Background tasks are coroutines, not threads. An
          idle cdin draws almost nothing and uses almost no CPU.
        </p>
      </div>
    </div>
  );
}
