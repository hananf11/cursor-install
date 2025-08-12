# Cursor AppImage Installer

A simple bash script to install Cursor (AI-powered code editor) on Linux.
Installing cursor on linux is unessasarly hard, this script makes it super easy. You can install it system-wide or user-specific.

## Quick Install (Single Command)

**System-wide installation:**
```bash
# Using curl
curl -sSL https://raw.githubusercontent.com/hananf11/cursor-install/main/install.sh | sudo bash

# Using wget
wget -qO- https://raw.githubusercontent.com/hananf11/cursor-install/main/install.sh | sudo bash
```

**User-specific installation:**
```bash
# Using curl
curl -sSL https://raw.githubusercontent.com/hananf11/cursor-install/main/install.sh | bash -- --local

# Using wget
wget -qO- https://raw.githubusercontent.com/hananf11/cursor-install/main/install.sh | bash -- --local
```

## Quick Start

**System-wide installation (requires sudo):**
```bash
sudo ./install.sh
```

**User-specific installation (no sudo required):**
```bash
./install.sh --local
```

## Install from Local AppImage

```bash
# System-wide
sudo ./install.sh /path/to/Cursor.AppImage

# User-specific
./install.sh --local /path/to/Cursor.AppImage
```

## Uninstall

**From menu:** Right-click Cursor → "Uninstall"

**From command line:**
```bash
# System installation
sudo /usr/local/bin/uninstall-cursor

# Local installation
~/.local/bin/uninstall-cursor
```

## Update

**From menu:** Right-click Cursor → "Update"

**From command line:**
```bash
# System installation
sudo /usr/local/bin/install-cursor

# Local installation
~/.local/bin/install-cursor
```

## Requirements

- Linux (tested on Fedora)
- Internet connection
- `curl` command
- Root privileges (only for system-wide installation)

## What it does

1. Downloads latest Cursor for your system
2. Installs to system or user directories
3. Adds to application menu with Uninstall/Update actions
4. Creates uninstall script for easy removal

The script is safe to run multiple times - it will uninstall any existing version before installing the new one.
