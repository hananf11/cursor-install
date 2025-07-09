# Cursor AppImage Installer

A simple bash script to install Cursor (AI-powered code editor) system-wide on Linux.

## Quick Start

```bash
sudo ./install.sh
```

That's it! The script will:
- Download the latest Cursor for your system
- Install it system-wide
- Add it to your application menu
- Create an uninstall script

## Alternative: Install from Local AppImage

```bash
sudo ./install.sh /path/to/Cursor.AppImage
```

## Uninstall

**Option 1:** Right-click Cursor in your app menu → "Uninstall"

**Option 2:** 
```bash
sudo /usr/local/bin/uninstall-cursor
```

## Update

Run the install script again to update to the latest version:
```bash
sudo ./install.sh
```

## Requirements

- Linux (tested on Fedora)
- Root privileges
- Internet connection
- `curl` command

## Troubleshooting

**Permission denied?** Make sure to use `sudo`

**Download fails?** Check your internet connection and try again

**Architecture not supported?** Currently supports x86_64 and ARM systems

## What it does

1. Detects your system architecture
2. Downloads latest Cursor from official API
3. Extracts and installs to `/usr/` directories
4. Creates desktop menu integration
5. Generates uninstall script

The script is safe to run multiple times - it will uninstall any existing version before installing the new one. 