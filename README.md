# c64.nvim

A comprehensive Neovim plugin for C64 Assembler development using Kick Assembler, featuring LSP support, VICE emulator integration, and helpful development tools.

## Features

- **LSP Integration**: Full Language Server Protocol support via [kickass_ls](https://github.com/cybersorcerer/kickass_ls)
  - Semantic token highlighting
  - Real-time diagnostics
  - Code completion
  - Symbol navigation
  - Advanced C64-specific analysis (zero-page optimization, hardware bug detection, etc.)

- **Build Integration**: Direct Kick Assembler compilation from Neovim
  - Automatic error parsing
  - Quickfix list integration
  - Success/error notifications

- **VICE Emulator Integration**: Launch and test your programs instantly
  - One-keypress execution
  - Automatic PRG file detection
  - Debug mode with VICE monitor and symbol file support
  - Remote monitor integration for advanced debugging

- **Telescope Integration**: Quick access to C64-specific references
  - **C64 Reference Manual Search** - Search and browse the complete C64 Programmer's Reference Guide directly in Neovim
  - Memory map browser
  - Register and constant lookup
  - Telescope quickfix integration for assembly errors

- **Diagnostic Display Modes**: Flexible diagnostic visualization
  - Virtual text mode (inline diagnostics)
  - Virtual lines mode (separate lines for diagnostics)
  - Signs only mode (minimal clutter)
  - Easy toggle between modes

- **Customizable**: Extensive configuration options for LSP, highlighting, and keybindings

## Prerequisites

Before installing c64.nvim, ensure you have the following:

1. **Neovim 0.11+** - Required for LSP features
2. **Java Runtime** - Required to run Kick Assembler
3. **Kick Assembler (kickass.jar)** - [Download here](http://theweb.dk/KickAssembler/)
4. **VICE Emulator** - [Download here](https://vice-emu.sourceforge.io/)
   - The `x64` binary must be in your PATH
5. **kickass_ls Language Server** - [Available here](https://github.com/cybersorcerer/kickass_ls)
   - The `kickass_ls` binary must be in your PATH
6. **nvim-lspconfig** - Required for LSP setup
7. **telescope.nvim** (optional) - For enhanced UI features

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add this to your lazy.nvim plugin configuration (usually in `~/.config/nvim/lua/plugins/` or in your `init.lua`):

```lua
return {
  "cybersorcerer/c64.nvim",
  dependencies = {
    "neovim/nvim-lspconfig", -- Required for LSP integration
    "nvim-telescope/telescope.nvim", -- Optional, for enhanced UI
  },
  ft = { "kickass" }, -- Lazy load only for Kick Assembler files
  config = function()
    require("c64").setup({
      -- Path to your kickass.jar file
      kickass_jar_path = vim.fn.expand("~/tools/kickass.jar"),

      -- Optional: customize paths if binaries are not in PATH
      -- vice_binary = "x64",
      -- kickass_ls_binary = "kickass_ls",
    })
  end,
}
```

**Note for Neovim 0.11+**: If you're using Neovim 0.11 or later, nvim-lspconfig is optional as c64.nvim uses the native `vim.lsp.config` API. However, it's still recommended for compatibility.

**Integration with existing LSP setup**: If you already have a centralized LSP configuration (e.g., using mason-lspconfig), c64.nvim will automatically integrate with it. Your global `LspAttach` autocmd will handle all keybindings for kickass_ls as well.

### Using Neovim's built-in package manager

Create the plugin directory (if it doesn't exist):

```bash
mkdir -p ~/.local/share/nvim/site/pack/c64/start
```

Clone the repository:

```bash
git clone https://github.com/yourusername/c64.nvim.git \
  ~/.local/share/nvim/site/pack/c64/start/c64.nvim
```

Install nvim-lspconfig as well:

```bash
git clone https://github.com/neovim/nvim-lspconfig.git \
  ~/.local/share/nvim/site/pack/c64/start/nvim-lspconfig
```

Add to your `init.lua`:

```lua
require("c64").setup({
  kickass_jar_path = vim.fn.expand("~/tools/kickass.jar"),
})
```

Restart Neovim.

## Configuration

### Full Configuration Example

```lua
require("c64").setup({
  -- Path to kickass.jar
  kickass_jar_path = vim.fn.expand("~/tools/kickass.jar"),

  -- VICE emulator binary name (must be in PATH)
  vice_binary = "x64",

  -- Language server binary name (must be in PATH)
  kickass_ls_binary = "kickass_ls",

  -- LSP configuration
  lsp = {
    settings = {
      kickass_ls = {
        warnUnusedLabels = false,
        zeroPageOptimization = {
          enabled = true,
          showHints = true,
        },
        branchDistanceValidation = {
          enabled = true,
          showWarnings = true,
        },
        illegalOpcodeDetection = {
          enabled = true,
          showWarnings = true,
        },
        hardwareBugDetection = {
          enabled = true,
          showWarnings = true,
          jmpIndirectBug = true,
        },
        memoryLayoutAnalysis = {
          enabled = true,
          showIOAccess = true,
          showStackWarnings = true,
          showROMWriteWarnings = true,
        },
        magicNumberDetection = {
          enabled = true,
          showHints = true,
          c64Addresses = true,
        },
        deadCodeDetection = {
          enabled = true,
          showWarnings = true,
        },
        styleGuideEnforcement = {
          enabled = true,
          showHints = true,
          upperCaseConstants = true,
          descriptiveLabels = true,
        },
      },
    },
  },

  -- Customize syntax highlighting
  highlight = {
    ['@lsp.type.mnemonic.kickass'] = { link = 'Function' },
    ['@lsp.type.directive.kickass'] = { link = 'Keyword' },
    ['@lsp.type.preprocessor.kickass'] = { link = 'PreProc' },
    ['@lsp.type.macro.kickass'] = { link = 'Macro' },
    ['@lsp.type.pseudocommand.kickass'] = { link = 'Special' },
    ['@lsp.type.function.kickass'] = { link = 'Function' },
    ['@lsp.type.label.kickass'] = { link = 'Label' },
    ['@lsp.type.number.kickass'] = { fg = '#ff9800' },
    ['@lsp.type.variable.kickass'] = { link = 'Identifier' },
  },

  -- Customize keybindings
  keymaps = {
    assemble = "<leader>ka",
    run_vice = "<leader>kr",
    debug_vice = "<leader>kd",
    show_diagnostics = "<leader>d",
  },
})
```

### Integration with Existing LSP Setup

If you already have a centralized LSP configuration (e.g., using `mason-lspconfig` or a global `LspAttach` autocmd), c64.nvim will integrate seamlessly:

#### Option 1: Let c64.nvim handle everything (recommended for most users)

- Just call `require("c64").setup()` as shown above
- c64.nvim will register kickass_ls and configure it automatically
- Your existing global LSP keybindings will work with kickass_ls

#### Option 2: Integrate with mason-lspconfig handlers

If you're using mason-lspconfig with custom handlers, you don't need to do anything special. c64.nvim registers kickass_ls as a custom server that works with your existing setup.

#### What c64.nvim configures

- LSP server registration and activation
- Diagnostic signs and virtual text styling
- Hover and signature help borders
- Semantic token highlighting for Kick Assembler

#### What c64.nvim does NOT configure

- LSP keybindings (uses your global `LspAttach` autocmd)
- General diagnostic behavior (only adds c64-specific enhancements)

This design ensures c64.nvim works harmoniously with your existing Neovim configuration.

## Keybindings

### Default Keymaps

#### Build & Run

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ka` | Assemble | Compile current file with Kick Assembler |
| `<leader>kr` | Run | Launch current program in VICE emulator |
| `<leader>kd` | Debug | Launch VICE with monitor and symbol file |

#### Diagnostics

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>d` | Show Diagnostics | Show line diagnostics in floating window |
| `<leader>dv` | Virtual Text Mode | Enable inline diagnostic text |
| `<leader>dl` | Virtual Lines Mode | Enable diagnostic lines (requires lsp_lines.nvim) |
| `<leader>ds` | Signs Only Mode | Show only diagnostic icons in sign column |
| `<leader>dt` | Toggle Mode | Cycle through diagnostic display modes |

#### C64 Reference & Tools

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>cr` | C64 Reference | Search C64 Programmer's Reference Manual |
| `<leader>cm` | Memory Map | Browse C64 memory map |
| `<leader>cR` | Registers | Browse C64 registers and constants |
| `<leader>td` | Telescope Diagnostics | Show all diagnostics (requires Telescope) |
| `<leader>ts` | Telescope Symbols | Show document symbols (requires Telescope) |

### LSP Keymaps

These are automatically set when editing Kick Assembler files:

| Key | Action | Description |
|-----|--------|-------------|
| `gD` | Go to Declaration | Jump to symbol declaration |
| `gd` | Go to Definition | Jump to symbol definition |
| `K` | Hover | Show documentation |
| `gi` | Go to Implementation | Jump to implementation |
| `<C-k>` | Signature Help | Show function signature |
| `gr` | References | Show all references |
| `<space>rn` | Rename | Rename symbol |
| `<space>ca` | Code Action | Show code actions |
| `<space>f` | Format | Format document |

## Commands

The plugin provides the following user commands:

| Command | Description |
|---------|-------------|
| `:C64Assemble` | Assemble the current file with Kick Assembler |
| `:C64Run` | Run the current program in VICE emulator |
| `:C64Debug` | Run the program in VICE with debug mode enabled |
| `:C64Enable` | Manually enable c64.nvim for current buffer |
| `:C64CreateMarker` | Create `.kickass` marker file in current directory |

## Telescope Extension

c64.nvim provides powerful Telescope integrations for enhanced development workflow:

### C64 Reference Manual Search

Press `<leader>cr` to search the complete C64 Programmer's Reference Guide:

- **Fuzzy search** through all sections (searches both titles and content)
- **Live preview** of sections as you navigate
- **Vertical split** display - see reference alongside your code
- **Markdown rendering** with syntax highlighting
- No need to leave Neovim or open PDFs!

**Usage:**

```vim
:Telescope c64 reference
# or use the keymap:
<leader>cr
```

Type to search (e.g., "sprite", "vic", "sid"), navigate with `j/k`, press `Enter` to open in a split.

### Memory Map & Registers

Browse C64 memory locations and hardware registers:

```vim
:Telescope c64 memory_map    # or <leader>cm
:Telescope c64 registers     # or <leader>cR
```

Select an entry to insert it at your cursor position.

## File Type Detection

The plugin uses intelligent multi-level detection to identify Kick Assembler files and avoid conflicts with other assemblers (NASM, MASM, etc.).

### Automatic Detection

Files with extensions `*.asm`, `*.s`, or `*.inc` are automatically analyzed using this strategy:

#### Level 1: Kick Assembler Directives (Most Reliable)

- Detects Kick Assembler-specific syntax like `.import`, `.macro`, `.namespace`, `.var`, etc.
- If found, filetype is set to `kickass`

#### Level 2: Project Marker File

- Searches for `.kickass`, `kickass.cfg`, or `.kickassembler` file in the project directory tree
- If found, all `.asm` files in that project are treated as Kick Assembler files

#### Level 3: C64-Specific Patterns (Hints)

- Detects C64-specific memory addresses and Kernal routines (e.g., `$D000`, `CHROUT`)
- Requires at least 2 C64-specific references to trigger

### Manual Activation

If automatic detection doesn't work, you can manually enable c64.nvim:

```vim
:C64Enable
```

This command sets the current buffer's filetype to `kickass` and activates all plugin features.

### Project Marker File

To ensure all `.asm` files in your project are recognized as Kick Assembler files, create a marker file:

```vim
:C64CreateMarker
```

This creates a `.kickass` file in your current working directory. All `.asm` files in this directory (and subdirectories) will automatically be detected as Kick Assembler files.

You can also manually create this file:

```bash
touch .kickass
```

Or create a `kickass.cfg` with your Kick Assembler configuration.

## Diagnostic Display Modes

c64.nvim offers flexible diagnostic visualization with three display modes:

### Virtual Text Mode (Default)

Diagnostics appear inline next to your code:

```asm
10: lda #$00    ● Error: Invalid syntax
```

### Virtual Lines Mode

Diagnostics appear in separate lines below the code (requires [lsp_lines.nvim](https://git.sr.ht/~whynothugo/lsp_lines.nvim)):

```asm
10: lda #$00
    ┗━ Error: Invalid syntax
```

### Signs Only Mode

Only icons appear in the sign column, minimal distraction:

```asm
󰅚 10: lda #$00
```

Use `<leader>d` to see full diagnostics in a floating window.

### Diagnostic Icons

- Error: 󰅚 (red alert circle)
- Warning: 󰀪 (yellow alert)
- Hint: 󰌶 (blue lightbulb)
- Info: 󰋽 (cyan information)

## Workflow Example

### Basic Development Cycle

1. **Open** a Kick Assembler file: `nvim myprogram.asm`
2. **Write** your code with LSP assistance (completions, diagnostics, etc.)
3. **Need help?** Press `<leader>cr` to search the C64 Reference Manual
4. **Assemble**: Press `<leader>ka` to compile
5. **Errors?** Telescope opens with clickable error list
6. **Fix** errors and reassemble
7. **Test**: Press `<leader>kr` to launch VICE and test your program
8. **Debug**: Press `<leader>kd` to launch VICE with monitor and symbols loaded

### Debugging with VICE Monitor

When you press `<leader>kd`, the plugin:
1. Starts VICE with the `-remotemonitor` flag (enables remote monitor on port 6510)
2. Automatically loads your `.sym` symbol file with `-moncommands`
3. Shows a notification with monitor activation instructions

**In VICE:**
- Press `Alt+H` to activate the monitor
- Use your labels directly in monitor commands (e.g., `break Main`, `d loop`)
- Monitor commands: `break`, `watch`, `d` (disassemble), `m` (memory), `r` (registers), `z` (continue)

**Example debug session:**
```
(monitor) break Main          # Set breakpoint at Main label
(monitor) z                   # Continue execution
(monitor) r                   # Show registers
(monitor) d Main Main+20      # Disassemble from Main to Main+$20
(monitor) m $0400 $04ff       # Show screen memory
```

### Using the C64 Reference

1. Press `<leader>cr` to open the reference search
2. Type to search (e.g., "sprite" or "vic")
3. See live preview in Telescope
4. Press `Enter` to open in vertical split
5. Reference stays open while you code
6. Press `q` to close the reference

## Troubleshooting

### LSP not starting

- Ensure `kickass_ls` is in your PATH: `which kickass_ls`
- Check Neovim's LSP logs: `:LspLog`

### Assembly fails

- Verify your `kickass_jar_path` is correct
- Ensure Java is installed: `java -version`
- Check the error in the quickfix list: `:copen`

### VICE not launching

- Ensure `x64` is in your PATH: `which x64`
- Make sure you assembled the file first (`<leader>ka`)
- Check that a `.prg` file was created

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT

## Credits

- Built for [Kick Assembler](http://theweb.dk/KickAssembler/) by Mads Nielsen
- Integrates with [VICE Emulator](https://vice-emu.sourceforge.io/)
- Uses [kickass_ls](https://github.com/cybersorcerer/kickass_ls) Language Server
