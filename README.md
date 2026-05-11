# nvim-json-graph

Interactive JSON graph viewer for Neovim with three modes:

- `browser` (default): local offline React app powered by `jsoncrack-react`
- `svg`: Graphviz render and open
- `split`: in-editor ASCII tree graph

The browser mode supports click-to-jump back into the source JSON buffer.

## Requirements

- Required: `node`, `pnpm`, `nvim`
- Optional: `dot` (for `:JsonGraph svg`), `xdg-open` (if `vim.ui.open` is unavailable)
- Build step for browser mode: `:JsonGraphBuild`

Health checks:

```vim
:checkhealth json_graph
```

## Copyright and Terms Notes

- This plugin does not bundle third-party installable artifacts such as `node_modules` or built web assets.
- Browser UI dependencies are installed separately via `pnpm` from `tools/json-graph-web/package.json`.
- The graph renderer dependency is `jsoncrack-react`, used as an external package with its own upstream license and terms.
- No code from the JSON Crack VS Code extension is redistributed as built vendor bundles in this repo.

## Commands

- `:JsonGraph [auto|browser|svg|split] [schema|data]`
- `:JsonGraphSchema`
- `:JsonGraphBuild`

## Install with vim.pack.add

```lua
vim.pack.add({
  { src = "https://github.com/<you>/nvim-json-graph.nvim", version = "main" },
})
```
## Offline Web Build

The browser UI is built from `tools/json-graph-web`.

Prerequisites:

- `node`
- `pnpm`

Build once from Neovim:

```vim
:JsonGraphBuild
```

Or build manually:

```bash
cd tools/json-graph-web
pnpm install
pnpm build
```
