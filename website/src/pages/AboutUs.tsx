import cdinimage from "../../../assets/CDIN-CODE.png";

export default function AboutPage() {
  return (
    <div className="">
      {/* Overview */}
      <div className="border-b">
        <div className="md:p-10 py-10 px-4">
          <h1 className="lg:text-2xl font-black text-xl">Overview</h1>
          <p className="text-muted-foreground mt-4">
            <span className="font-semibold text-foreground text-base">
              [<span className="text-primary relative -top-px">*</span>]
            </span>{" "}
            cdin is a small, fast, keyboard-driven text editor with vim-style
            modal editing on by default. The core is written in C; everything
            else is Lua you can actually read, change, and recompile-free.
          </p>
        </div>
      </div>

      {/* Why choose cdin */}
      <div className="border-b">
        <div className="md:p-10 py-10 px-4">
          <h1 className="flex items-start gap-1 lg:text-2xl font-semibold text-xl">
            Why choose cdin
          </h1>
          <div className="mt-8 space-y-4">
            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              Modal editing built in and on by default. Vim-style Normal /
              Insert / Visual modes work out of the box.
            </p>

            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              The codebase is meant to be readable. You should be able to find
              the edit loop, understand what it does, and change it. Functions
              are short. Modules are small. There are no clever abstractions
              that require you to know the whole project before touching any of
              it.
            </p>

            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              Features belong in plugins. The core does the minimum that every
              editor needs. Anything optional is in data/plugins/ where it can
              be read, copied, modified, or replaced without touching the core.
              This is how lite-xl approaches things too, and it works.
            </p>

            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              Startup time and memory use matter. The renderer only redraws what
              actually changed. Background tasks are coroutines, not threads. An
              idle cdin draws almost nothing and uses almost no CPU.
            </p>

            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              Everything is Lua — commands, keybindings, UI behavior, syntax
              highlighting — all plain Lua loaded from data/ at startup. No
              recompiling required.
            </p>

            <p className="text-muted-foreground lg:text-base text-sm">
              <span className="font-semibold text-foreground text-base">
                [<span className="text-primary relative -top-px">*</span>]
              </span>{" "}
              Configurable through data/user/init.lua — plain Lua, no DSL.
              Change themes, keybindings, or any behavior you can imagine.
            </p>
          </div>
        </div>
      </div>

      {/* Screenshot */}
      <div className="border-b">
        <div className="md:p-10 py-10 px-4">
          <div className="border-4 rounded-lg hover:border-primary duration-100 hover:scale-101 p-2">
            <img
              src={cdinimage}
              alt="cdin editor in action"
              className="w-full aspect-video object-cover rounded"
            />
          </div>
        </div>
      </div>

      {/* For whom */}
      <div className="md:p-10 px-4 py-10">
        <h1 className="flex items-start gap-1 lg:text-2xl font-semibold text-xl">
          For whom
        </h1>
        <p className="text-muted-foreground mt-4">
          <span className="font-semibold text-foreground text-base">
            [<span className="text-primary relative -top-px">*</span>]
          </span>{" "}
          cdin is for people who want a small, fast editor they can actually
          make their own. If you've used vim, the basics transfer directly. If
          you're curious how an editor works, the whole thing is readable and
          modifiable. If you just want a quick, quiet tool to open files and get
          out of the way, that works too.
        </p>
      </div>
    </div>
  );
}
