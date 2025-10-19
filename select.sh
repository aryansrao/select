#!/bin/bash

set -e

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Detect shell configuration file
detect_shell_rc() {
    if [[ "$SHELL" == *"zsh"* ]]; then
        echo "$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        [[ "$(uname)" == "Darwin" ]] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc"
    else
        echo "$HOME/.profile"
    fi
}

readonly SHELL_RC=$(detect_shell_rc)
readonly INSTALL_DIR="$HOME/.local/bin"
readonly APP_NAME="select"

# Reload shell configuration
reload_shell() {
    [[ -f "$SHELL_RC" ]] && source "$SHELL_RC" 2>/dev/null || true
    alias select='select' 2>/dev/null || true
    export PATH="$INSTALL_DIR:$PATH"
}

# Check installation status
is_installed() {
    [[ -f "$INSTALL_DIR/$APP_NAME" ]] && grep -q "alias select=" "$SHELL_RC" 2>/dev/null
}

# Display menu
show_menu() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║      Select - TUI - Easy Operations    ║"
    echo -e "╚════════════════════════════════════════╝${NC}\n"
    
    if is_installed; then
        echo -e "${GREEN}● Status: Installed${NC}\n"
        echo "  1) Uninstall"
        echo "  2) Reinstall"
        echo "  3) Exit"
    else
        echo -e "${YELLOW}○ Status: Not Installed${NC}\n"
        echo "  1) Install"
        echo "  2) Exit"
    fi
    
    echo -ne "\n${CYAN}→${NC} Choose option: "
}

# Installation
install_app() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║            Installation                ║"
    echo -e "╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}[1/4]${NC} Creating directory..."
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${BLUE}[2/4]${NC} Installing application..."
    cat > "$INSTALL_DIR/$APP_NAME" << 'EOFPYTHON'
#!/usr/bin/env python3
"""Modern TUI File Manager - Clean & Minimal Interface"""

import os
import sys
import shutil
from pathlib import Path
from datetime import datetime
import curses

class FileManager:
    """Minimalist terminal file manager"""
    
    def __init__(self, stdscr, start_dir="."):
        self.stdscr = stdscr
        self.current_dir = Path(start_dir).resolve()
        self.selected = set()
        self.clipboard = []
        self.clipboard_mode = None
        self.index = 0
        self.scroll = 0
        self.files = []
        self.show_hidden = False
        self.filter = ""
        self.message = ""
        self.msg_error = False
        
        self._init_colors()
        curses.curs_set(0)
        self.stdscr.clear()
        self.refresh_files()
    
    def _init_colors(self):
        """Initialize color pairs"""
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)    # Directories
        curses.init_pair(2, curses.COLOR_GREEN, -1)   # Selected
        curses.init_pair(3, curses.COLOR_YELLOW, -1)  # Info
        curses.init_pair(4, curses.COLOR_RED, -1)     # Error
        curses.init_pair(5, curses.COLOR_BLUE, -1)    # Header
        curses.init_pair(6, curses.COLOR_MAGENTA, -1) # Highlight
    
    def refresh_files(self):
        """Refresh file list"""
        try:
            files = list(self.current_dir.iterdir())
            
            if not self.show_hidden:
                files = [f for f in files if not f.name.startswith('.')]
            
            if self.filter:
                files = [f for f in files if self.filter.lower() in f.name.lower()]
            
            self.files = sorted(files, key=lambda x: (not x.is_dir(), x.name.lower()))
            
            if self.current_dir.parent != self.current_dir:
                self.files.insert(0, self.current_dir.parent)
            
            self.index = min(self.index, max(0, len(self.files) - 1))
            
        except PermissionError:
            self._show_msg("Permission denied", error=True)
            self.current_dir = self.current_dir.parent
            self.refresh_files()
    
    def _show_msg(self, msg, error=False):
        """Display status message"""
        self.message = msg
        self.msg_error = error
    
    def _format_size(self, size):
        """Format file size"""
        for unit in ['B', 'K', 'M', 'G', 'T']:
            if size < 1024:
                return f"{size:>5.0f}{unit}" if size >= 100 else f"{size:>5.1f}{unit}"
            size /= 1024
        return f"{size:>5.1f}P"
    
    def _get_info(self, path):
        """Get file information"""
        try:
            stat = path.stat()
            size = "  DIR" if path.is_dir() else self._format_size(stat.st_size)
            mtime = datetime.fromtimestamp(stat.st_mtime).strftime('%m/%d %H:%M')
            return size, mtime
        except:
            return "    ?", "     ?"
    
    def draw(self):
        """Draw the interface"""
        self.stdscr.clear()
        height, width = self.stdscr.getmaxyx()
        
        # Header - Current directory
        header = f" {self.current_dir} "
        self.stdscr.attron(curses.color_pair(5) | curses.A_BOLD)
        self.stdscr.addstr(0, 0, header[:width-1].ljust(width-1))
        self.stdscr.attroff(curses.color_pair(5) | curses.A_BOLD)
        
        # Info bar
        info_parts = []
        if self.selected:
            info_parts.append(f"{len(self.selected)} selected")
        if self.clipboard:
            mode = "cut" if self.clipboard_mode == 'cut' else "copy"
            info_parts.append(f"{len(self.clipboard)} in clipboard ({mode})")
        if self.filter:
            info_parts.append(f"filter: {self.filter}")
        
        if info_parts:
            info = " │ ".join(info_parts)
            self.stdscr.addstr(1, 0, f" {info} "[:width-1], curses.color_pair(3))
            list_start = 2
        else:
            list_start = 1
        
        # File list
        list_height = height - list_start - 2
        
        # Auto-scroll
        if self.index < self.scroll:
            self.scroll = self.index
        elif self.index >= self.scroll + list_height:
            self.scroll = self.index - list_height + 1
        
        for i in range(list_height):
            idx = i + self.scroll
            if idx >= len(self.files):
                break
            
            file_path = self.files[idx]
            is_parent = (idx == 0 and len(self.files) > 0 and 
                        self.files[0] == self.current_dir.parent)
            
            name = ".." if is_parent else file_path.name
            size, mtime = self._get_info(file_path)
            
            # Selection indicator
            sel = "●" if file_path in self.selected else " "
            
            # Cursor
            cursor = "▸" if idx == self.index else " "
            
            # Format line
            max_name = width - 30
            if len(name) > max_name:
                name = name[:max_name-3] + "..."
            
            line = f"{cursor} {sel} {name:<{max_name}} {size} {mtime}"
            line = line[:width-1]
            
            # Apply colors
            attr = curses.A_NORMAL
            if idx == self.index:
                attr = curses.color_pair(6) | curses.A_BOLD
            elif file_path in self.selected:
                attr = curses.color_pair(2)
            elif file_path.is_dir():
                attr = curses.color_pair(1)
            
            try:
                self.stdscr.addstr(list_start + i, 0, line, attr)
            except curses.error:
                pass
        
        # Footer - Help text
        help_txt = " ␣:select  c:copy  x:cut  v:paste  d:delete  h:hidden  /:filter  q:quit "
        self.stdscr.addstr(height-2, 0, help_txt[:width-1], curses.A_DIM)
        
        # Status message
        if self.message:
            color = curses.color_pair(4) if self.msg_error else curses.color_pair(2)
            try:
                self.stdscr.addstr(height-1, 0, f" {self.message}"[:width-1], color)
            except curses.error:
                pass
        
        self.stdscr.refresh()
    
    def _get_input(self, prompt):
        """Get user input"""
        height, width = self.stdscr.getmaxyx()
        curses.echo()
        curses.curs_set(1)
        self.stdscr.addstr(height-1, 0, " " * (width-1))
        self.stdscr.addstr(height-1, 0, f" {prompt}")
        self.stdscr.refresh()
        
        try:
            result = self.stdscr.getstr(height-1, len(prompt) + 2, width-len(prompt)-3).decode('utf-8')
        except:
            result = ""
        
        curses.noecho()
        curses.curs_set(0)
        return result.strip()
    
    def _copy(self):
        """Copy selected files"""
        if not self.selected:
            self._show_msg("Nothing selected", error=True)
            return
        
        self.clipboard = list(self.selected)
        self.clipboard_mode = 'copy'
        self._show_msg(f"Copied {len(self.clipboard)} items")
        self.selected.clear()
    
    def _cut(self):
        """Cut selected files"""
        if not self.selected:
            self._show_msg("Nothing selected", error=True)
            return
        
        self.clipboard = list(self.selected)
        self.clipboard_mode = 'cut'
        self._show_msg(f"Cut {len(self.clipboard)} items")
        self.selected.clear()
    
    def _paste(self):
        """Paste files from clipboard"""
        if not self.clipboard:
            self._show_msg("Clipboard empty", error=True)
            return
        
        try:
            for src in self.clipboard:
                dest = self.current_dir / src.name
                
                # Handle conflicts
                if dest.exists() and dest != src:
                    base = src.stem
                    ext = src.suffix
                    counter = 1
                    while dest.exists():
                        dest = self.current_dir / f"{base}_{counter}{ext}"
                        counter += 1
                
                if dest == src:
                    continue
                
                if self.clipboard_mode == 'cut':
                    shutil.move(str(src), str(dest))
                else:
                    if src.is_dir():
                        shutil.copytree(src, dest)
                    else:
                        shutil.copy2(src, dest)
            
            action = "Moved" if self.clipboard_mode == 'cut' else "Copied"
            self._show_msg(f"{action} {len(self.clipboard)} items")
            
            if self.clipboard_mode == 'cut':
                self.clipboard.clear()
                self.clipboard_mode = None
            
            self.refresh_files()
            
        except Exception as e:
            self._show_msg(f"Error: {str(e)}", error=True)
    
    def _delete(self):
        """Delete selected files"""
        if not self.selected:
            self._show_msg("Nothing selected", error=True)
            return
        
        confirm = self._get_input(f"Delete {len(self.selected)} items? (y/n):")
        if confirm.lower() != 'y':
            self._show_msg("Cancelled")
            return
        
        try:
            for path in self.selected:
                if path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink()
            
            self._show_msg(f"Deleted {len(self.selected)} items")
            self.selected.clear()
            self.refresh_files()
            
        except Exception as e:
            self._show_msg(f"Error: {str(e)}", error=True)
    
    def run(self):
        """Main event loop"""
        while True:
            self.draw()
            
            try:
                key = self.stdscr.getch()
            except KeyboardInterrupt:
                break
            
            # Navigation
            if key in (ord('q'), ord('Q')):
                break
            elif key in (curses.KEY_UP, ord('k')):
                self.index = max(0, self.index - 1)
            elif key in (curses.KEY_DOWN, ord('j')):
                self.index = min(len(self.files) - 1, self.index + 1)
            elif key == curses.KEY_PPAGE:  # Page Up
                self.index = max(0, self.index - 10)
            elif key == curses.KEY_NPAGE:  # Page Down
                self.index = min(len(self.files) - 1, self.index + 10)
            elif key == curses.KEY_HOME:
                self.index = 0
            elif key == curses.KEY_END:
                self.index = len(self.files) - 1
            
            # Selection
            elif key == ord(' '):
                if self.files and self.index < len(self.files):
                    file = self.files[self.index]
                    if not (self.index == 0 and file == self.current_dir.parent):
                        if file in self.selected:
                            self.selected.remove(file)
                        else:
                            self.selected.add(file)
                    self.index = min(len(self.files) - 1, self.index + 1)
            
            # Open directory
            elif key in (ord('\n'), curses.KEY_ENTER, 10, ord('l')):
                if self.files and self.index < len(self.files):
                    file = self.files[self.index]
                    if file.is_dir():
                        self.current_dir = file
                        self.index = 0
                        self.scroll = 0
                        self.refresh_files()
                        self.message = ""
            
            # File operations
            elif key == ord('c'):
                self._copy()
            elif key == ord('v'):
                self._paste()
            elif key == ord('x'):
                self._cut()
            elif key == ord('d'):
                self._delete()
            elif key == ord('X'):
                self.clipboard.clear()
                self.clipboard_mode = None
                self._show_msg("Clipboard cleared")
            
            # Toggle & Filter
            elif key == ord('h'):
                self.show_hidden = not self.show_hidden
                self.refresh_files()
                self._show_msg(f"Hidden: {'shown' if self.show_hidden else 'hidden'}")
            elif key == ord('/'):
                self.filter = self._get_input("Filter:")
                self.refresh_files()
            elif key == 27:  # ESC
                if self.filter:
                    self.filter = ""
                    self.refresh_files()
                    self._show_msg("Filter cleared")
            
            # Select all/none
            elif key == ord('a'):
                self.selected = {f for f in self.files if f != self.current_dir.parent}
                self._show_msg(f"Selected {len(self.selected)} items")
            elif key == ord('A'):
                self.selected.clear()
                self._show_msg("Selection cleared")

def main(stdscr):
    start_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    app = FileManager(stdscr, start_dir)
    app.run()

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        sys.exit(0)
EOFPYTHON

    chmod +x "$INSTALL_DIR/$APP_NAME"
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${BLUE}[3/4]${NC} Configuring shell..."
    cp "$SHELL_RC" "${SHELL_RC}.backup.$(date +%s)" 2>/dev/null || true
    
    # Clean old entries
    sed -i.tmp '/alias select=/d; /# File Manager/d; /export PATH=.*\.local\/bin/d' "$SHELL_RC" 2>/dev/null || true
    rm -f "${SHELL_RC}.tmp" 2>/dev/null || true
    
    # Add new configuration using echo (more reliable than heredoc)
    echo "" >> "$SHELL_RC"
    echo "# File Manager" >> "$SHELL_RC"
    echo "alias select='$INSTALL_DIR/$APP_NAME'" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
    
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${BLUE}[4/4]${NC} Activating..."
    reload_shell
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║      Installation Successful! ✓        ║"
    echo -e "╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  ${GREEN}select${NC}             Open current directory"
    echo -e "  ${GREEN}select ~/path${NC}      Open specific path\n"
    
    echo -e "${CYAN}Keys:${NC}"
    echo -e "  ␣ Select    c Copy      x Cut"
    echo -e "  ↑↓ Navigate v Paste     d Delete"
    echo -e "  ⏎ Open      h Hidden    / Filter"
    echo -e "  a All       A Clear     q Quit\n"
    
    echo -e "${YELLOW}Note:${NC} Restart terminal or run: ${CYAN}source $SHELL_RC${NC}\n"
    read -p "Press Enter to continue..."
}

# Uninstallation
uninstall_app() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗"
    echo -e "║          Uninstallation                ║"
    echo -e "╚════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BLUE}[1/3]${NC} Removing files..."
    rm -f "$INSTALL_DIR/$APP_NAME"
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${BLUE}[2/3]${NC} Cleaning configuration..."
    cp "$SHELL_RC" "${SHELL_RC}.uninstall_backup.$(date +%s)" 2>/dev/null || true
    sed -i.tmp '/alias select=/d; /# File Manager/d; /export PATH=.*\.local\/bin/d' "$SHELL_RC" 2>/dev/null || true
    rm -f "${SHELL_RC}.tmp" 2>/dev/null || true
    unalias select 2>/dev/null || true
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${BLUE}[3/3]${NC} Finalizing..."
    echo -e "${GREEN}  ✓ Complete${NC}\n"
    
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║    Uninstallation Successful! ✓        ║"
    echo -e "╚════════════════════════════════════════╝${NC}\n"
    
    read -p "Press Enter to continue..."
}

# Main loop
main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                if is_installed; then
                    uninstall_app
                else
                    install_app
                fi
                ;;
            2)
                if is_installed; then
                    uninstall_app
                    sleep 1
                    install_app
                else
                    echo -e "\n${CYAN}Goodbye!${NC}"
                    exit 0
                fi
                ;;
            3)
                echo -e "\n${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

main