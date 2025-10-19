# select — Minimal TUI File Manager

A small, dependency-light terminal user interface (TUI) for basic file operations: browse directories, select files, copy/cut/paste, delete, filter and toggle hidden files. The project is intended to be installed as a single command-line application named `select` and provides an installer script (`select.sh`) that sets up a Python-based TUI binary in `~/.local/bin` and adds a shell alias for convenience.

---

## Overview

`select` is designed to be minimal, fast, and easy to use from any POSIX-compatible shell. The installer script `select.sh` bundles a standalone Python3 script into `~/.local/bin/select` and updates the user's shell configuration (for example `~/.zshrc` or `~/.bashrc`) to add an alias and prepend `~/.local/bin` to `PATH`.

Key features

- Navigate the filesystem in a curses-based TUI
- Select multiple files
- Copy, cut and paste files and directories with conflict resolution
- Delete selected files with confirmation
- Toggle hidden files and filter by name
- Small single-file installation and uninstallation

---

## Requirements

- Unix-like system (Linux, macOS)
- Python 3.6+ with the `curses` module available (macOS ships curses; on some Linux systems you may need `libncurses` and the Python curses bindings)
- A POSIX shell (zsh, bash, etc.) to run the installer

The tool attempts to detect your shell profile (`~/.zshrc` or `~/.bashrc` / `~/.bash_profile`) and update it. It creates `~/.local/bin` if missing.

---

## Installation

In order to install: using the included `select.sh` installer script.

1) By the repository:

```bash
git clone https://github.com/aryansrao/select.git && cd select && bash select.sh
```

2) Install directly from GitHub (raw installer) — one-liner using `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/aryansrao/select/main/select.sh -o /tmp/select.sh
bash /tmp/select.sh
```

3) Download only the runtime (advanced):

If you prefer to install only the Python runtime created by the installer, run the installer on another machine or extract the code block from the installer and place it into `~/.local/bin/select`, then make it executable:

```bash
# create target dir if missing
mkdir -p "$HOME/.local/bin"

# write the python script to ~/.local/bin/select and make executable
curl -fsSL https://raw.githubusercontent.com/aryansrao/select/main/select.sh | sed -n '/^cat > "\$INSTALL_DIR\/$APP_NAME" << \x27EOFPYTHON\x27/,/^EOFPYTHON$/p' | sed '1d;$d' > "$HOME/.local/bin/select"
chmod +x "$HOME/.local/bin/select"

# add to PATH (append to your shell rc if you want persistent access)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"  # adapt to your shell
source "$HOME/.zshrc"
```

Note: the previous command extracts the embedded Python program from the installer script. Use with care and verify the downloaded content.

---

## Uninstallation

To uninstall using the installer helper (if previously installed via `select.sh`), run the installer script and choose `Uninstall` from the menu or run the `select.sh` and choose the appropriate option.

Manually remove:

```bash
rm -f "$HOME/.local/bin/select"
# remove alias and PATH lines from your shell rc (example for zsh):
sed -i.bak '/# File Manager/d; /alias select=/d; /export PATH=.*\.local\/bin/d' "$HOME/.zshrc"
source "$HOME/.zshrc"
```

The installer also creates backups of your shell rc before editing (timestamped backups in the same directory).

---

## Usage

Launch the file manager by typing:

```bash
select            # opens current directory
select ~/some/path  # open a specific path
```

Basic keys (inside the TUI)

- Up / k: move cursor up
- Down / j: move cursor down
- Space: toggle select for the highlighted item
- Enter / l: open directory
- c: copy selected
- x: cut selected
- v: paste clipboard into current directory
- d: delete selected (prompts for confirmation)
- X: clear clipboard
- h: toggle hidden files
- /: enter a filter string (Esc clears the filter)
- a: select all visible items
- A: clear selection
- q: quit

Notes on behavior

- When pasting, name conflicts are auto-resolved by appending _1, _2, ... to the filename until an unused name is found.
- Deleting directories uses recursive deletion.

---

## Example workflows and curl commands

Install via curl and run immediately:

```bash
curl -fsSL https://raw.githubusercontent.com/aryansrao/select/main/select.sh -o /tmp/select.sh && bash /tmp/select.sh
```

Download only the runtime (extract from installer) and inspect before installing:

```bash
curl -fsSL https://raw.githubusercontent.com/aryansrao/select/main/select.sh -o /tmp/select.sh
sed -n '/^cat > "\$INSTALL_DIR\/$APP_NAME" << \x27EOFPYTHON\x27/,/^EOFPYTHON$/p' /tmp/select.sh > /tmp/select_runtime_block.txt
# inspect the extracted runtime
less /tmp/select_runtime_block.txt
# once satisfied, extract the inner block (remove the heredoc markers) and write to ~/.local/bin/select
sed -n '2,$p' /tmp/select_runtime_block.txt | sed '$d' > "$HOME/.local/bin/select"
chmod +x "$HOME/.local/bin/select"
```

Run the TUI against a directory mounted over the network or an external drive to perform bulk file operations safely:

```bash
select /Volumes/ExternalDrive/Downloads
```

---

## Configuration and internals

- Installer script: `select.sh` (Bash)
  - Detects user shell and chooses a shell rc file (`~/.zshrc`, `~/.bashrc` or `~/.bash_profile`) to update
  - Creates `~/.local/bin` and writes the embedded Python runtime into `~/.local/bin/select`
  - Makes runtime executable and appends an alias `alias select="$HOME/.local/bin/select"` and `export PATH="$HOME/.local/bin:$PATH"` to the shell rc
  - Backups of the shell rc are created before modification

- Runtime: single-file Python TUI using `curses`
  - Main class: `FileManager` built around a curses event loop
  - Core state: `current_dir`, `selected` (set), `clipboard` (list) and `clipboard_mode` ('copy'|'cut')
  - File operations rely on `shutil` and `pathlib` for cross-platform behavior

Security and safety

- The runtime performs destructive operations (delete, move). Use with care. There is a confirmation prompt before deletion.
- When running installer commands fetched from the web, inspect the script before running.

