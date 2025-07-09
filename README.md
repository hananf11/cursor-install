# Cursor AppImage Installer

A bash script for downloading and installing Cursor (the AI-powered code editor) as a system-wide application on Linux systems.

## What is this project?

This project provides an automated installation script for Cursor, an AI-powered code editor built on VS Code. The script downloads the latest stable version of Cursor for your system architecture and installs it system-wide, making it available to all users on the system.

## Features

- **Automatic Download**: Fetches the latest stable version of Cursor from the official API
- **Architecture Detection**: Automatically detects your system architecture (x86_64 or ARM)
- **System-wide Installation**: Installs Cursor to `/usr/` directories for all users
- **Clean Uninstallation**: Creates an uninstall script for easy removal
- **Desktop Integration**: Adds the application to your system's application menu
- **AppImage Support**: Can also install from a local AppImage file

## Prerequisites

- Linux system (x86_64 or ARM architecture)
- Root privileges (for system-wide installation)
- Internet connection (for downloading)
- `curl` command-line tool

## Usage

### Option 1: Download and Install Latest Version

```bash
sudo ./install.sh
```

This will:
1. Detect your system architecture
2. Download the latest stable version of Cursor
3. Extract and install it system-wide
4. Create desktop menu entries
5. Generate an uninstall script

### Option 2: Install from Local AppImage

```bash
sudo ./install.sh /path/to/your/Cursor.AppImage
```

This will install Cursor from a local AppImage file instead of downloading it.

## What the script does

1. **Platform Detection**: Determines if you're running on x86_64 or ARM architecture
2. **Download**: Fetches the latest Cursor AppImage from the official API
3. **Extraction**: Extracts the AppImage contents to a temporary directory
4. **Installation**: Copies files to system directories (`/usr/`)
5. **Integration**: Creates desktop menu entries and updates the desktop database
6. **Cleanup**: Removes temporary files and creates an uninstall script

## Installation Locations

The script installs Cursor to standard system directories:
- Binary files: `/usr/bin/`
- Desktop files: `/usr/share/applications/`
- Icons: `/usr/share/icons/`
- Other resources: `/usr/share/`

## Uninstallation

### Method 1: Desktop Menu
Right-click on Cursor in your application menu and select "Uninstall"

### Method 2: Command Line
```bash
sudo /usr/local/bin/uninstall-cursor
```

The uninstall script will:
- Remove all installed files
- Remove app-specific directories
- Clean up the uninstall script itself
- Update desktop and MIME databases

## Troubleshooting

### Permission Denied
Make sure to run the script with `sudo`:
```bash
sudo ./install.sh
```

### Architecture Not Supported
The script currently supports:
- x86_64 (64-bit Intel/AMD)
- ARM (ARMv7, ARMv8, AArch64)

### Download Failures
- Check your internet connection
- Verify that `curl` is installed
- Try running the script again

### Installation Issues
- Ensure you have sufficient disk space
- Check that `/usr/` directories are writable
- Verify that the AppImage file is not corrupted

## File Structure

```
.
├── install.sh          # Main installation script
└── README.md          # This file
```

## How it works

The script uses the official Cursor API to fetch download information:
- API URL: `https://cursor.com/api/download?releaseTrack=stable`
- Automatically selects the correct platform version
- Downloads the AppImage and extracts it
- Installs files to system directories
- Creates desktop integration

## Contributing

Feel free to submit issues or pull requests to improve the installation script.

## License

This project is open source. Please check the license terms of Cursor itself for usage restrictions. 