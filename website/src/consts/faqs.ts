export const faqs = [
  {
    question: "What is cdin?",
    answer:
      "cdin is a small, fast, keyboard-driven text editor with Vim-style modal editing enabled by default. Its core is written in C (handling the window, renderer, and SDL bindings), while the actual editor logic, commands, keybindings, UI, and plugins live in readable Lua loaded from data/ at startup. You can change almost everything without recompiling.",
  },
  {
    question: "How do I build and run cdin?",
    answer:
      "Clone the repo, then run make (requires gcc, make, SDL3, and Lua 5.4). Launch it with ./build/linux-release/cdin . or open a specific file. Alternatively, use the helper script: python3 scripts/cdin.py build-install. See the Building from Source guide for dependencies and platform notes.",
  },
  {
    question: "Does cdin use Vim-style editing?",
    answer:
      "Yes. Modal editing (Normal / Insert / Visual) is built-in and on by default. Every buffer starts in Normal mode, and the status bar always shows the current mode ([NORMAL], [INSERT], or [VISUAL]). Basic Vim motions and operators transfer directly; the Vim Keybindings guide covers the rest, including ex commands and the m action menu.",
  },
  {
    question: "How do I configure cdin or change keybindings/themes?",
    answer:
      "Configuration is plain Lua in data/user/init.lua (no special DSL). Themes are single Lua files—three are bundled, and you can write your own. Keybindings, syntax highlighting, and most behavior can be customized the same way. Project-local config is also supported. See the Configuration and Themes guides.",
  },
  {
    question: "What features does it include?",
    answer:
      "Modal editing, ex command line (:w, :q, :e, :!cmd, etc.), project tree with optional git status markers, multi-tab + split panes, project-wide search, fuzzy file finder (Ctrl+P), session restore, syntax highlighting for C/Lua/Markdown/Python/JS/TS, trailing whitespace trimming on save, relative or absolute line numbers, and a plugin system. Optional features live in data/plugins/.",
  },
  {
    question: "Can I extend cdin with plugins?",
    answer:
      "Yes. Features belong in plugins. The core stays minimal; anything optional lives in data/plugins/ so you can read, copy, modify, or replace it without touching the core. The Plugins guide covers the bundled plugins and the plugin API.",
  },
];
