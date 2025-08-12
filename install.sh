#!/bin/bash

# install.sh - Script to download, extract, and install an AppImage
# Usage: ./install.sh [--local] [/path/to/your.AppImage]

set -e  # Exit on any error

# Global variables
LOCAL_INSTALL=false
SCRIPT_PATH=""

# Function to detect platform
detect_platform() {
  # Determine the system architecture
  ARCH=$(uname -m)
  
  case "$ARCH" in
    x86_64)
      PLATFORM="linux-x64"
      ;;
    armv7l|armv8*|aarch64)
      PLATFORM="linux-arm"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac
}

API_URL_BASE="https://cursor.com/api/download?releaseTrack=stable"

# Function to get installation base directory
get_install_base() {
  if [ "$LOCAL_INSTALL" = true ]; then
    echo "$HOME/.local"
  else
    echo "/opt"
  fi
}

# Function to get bin directory
get_bin_dir() {
  if [ "$LOCAL_INSTALL" = true ]; then
    echo "$HOME/.local/bin"
  else
    echo "/usr/local/bin"
  fi
}

# Function to get applications directory
get_applications_dir() {
  if [ "$LOCAL_INSTALL" = true ]; then
    echo "$HOME/.local/share/applications"
  else
    echo "/usr/share/applications"
  fi
}

# Function to check if the script is run as root
check_root() {
  if [ "$LOCAL_INSTALL" = false ] && [ "$EUID" -ne 0 ]; then
    echo "Please run as root (with sudo) or use --local flag for user installation"
    exit 1
  fi
}

# Function to download the AppImage from the server
download_appimage() {
  local api_url="${API_URL_BASE}&platform=${PLATFORM}"
  echo "Fetching app information from $api_url..."
  RESPONSE_JSON=$(curl -s "$api_url")

  if [ $? -ne 0 ] || [ -z "$RESPONSE_JSON" ]; then
    echo "Error: Failed to fetch app information."
    exit 1
  fi

  DOWNLOAD_URL=$(echo "$RESPONSE_JSON" | grep -oP '(?<="downloadUrl":")[^"]*')

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Failed to find download URL in the response."
    exit 1
  fi

  APPIMAGE_PATH=$(mktemp /tmp/Cursor-XXXXXX.AppImage)
  echo "Downloading AppImage from $DOWNLOAD_URL..."
  curl -L "$DOWNLOAD_URL" -o "$APPIMAGE_PATH"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to download the AppImage."
    exit 1
  fi
}

# Function to extract the AppImage
extract_appimage() {
  local temp_dir="$1"

  echo "Extracting AppImage: $APPIMAGE_PATH"
  "$APPIMAGE_PATH" --appimage-extract -o "$temp_dir" 2>/dev/null || \
    ( cd "$temp_dir" && "$APPIMAGE_PATH" --appimage-extract )

  if [ ! -d "$temp_dir/squashfs-root" ]; then
    echo "Error: AppImage extraction failed"
    rm -rf "$temp_dir"
    exit 1
  fi
}

# Function to uninstall existing installation
uninstall_existing() {
  local bin_dir=$(get_bin_dir)
  local uninstall_script="$bin_dir/uninstall-$APP_DIR"
  if [ -x "$uninstall_script" ]; then
    echo "Existing installation found. Uninstalling..."
    "$uninstall_script"
  fi
}

# Function to install the application
install_app() {
  local install_base=$(get_install_base)
  local bin_dir=$(get_bin_dir)
  mkdir -p "$install_base/$APP_DIR"

  echo "Creating file tracking list for easy uninstallation..."
  local exclude_pattern=""
  for dir in "${APP_SPECIFIC_DIRS[@]}"; do
    local rel_dir="${dir#/usr/}"
    exclude_pattern="${exclude_pattern:+$exclude_pattern|}$rel_dir"
  done

  if [ -n "$exclude_pattern" ]; then
    find usr -type f | grep -v -E "$exclude_pattern" > "$install_base/$APP_DIR/installed_files.txt"
  else
    find usr -type f > "$install_base/$APP_DIR/installed_files.txt"
  fi

  if [ ${#APP_SPECIFIC_DIRS[@]} -gt 0 ]; then
    printf "%s\n" "${APP_SPECIFIC_DIRS[@]}" > "$install_base/$APP_DIR/app_directories.txt"
  fi

  if [ "$LOCAL_INSTALL" = true ]; then
    echo "Copying files to user directories..."
    mkdir -p "$HOME/.local"
    cp -r usr/* "$HOME/.local/"
  else
    echo "Copying files to system directories..."
    cp -r usr/* /usr/
  fi

  # Create symbolic link for the cursor binary
  if [ -f "/usr/share/cursor/bin/cursor" ]; then
    echo "Creating symbolic link for cursor binary..."
    mkdir -p "$bin_dir"
    ln -sf "/usr/share/cursor/bin/cursor" "$bin_dir/cursor"
    echo "cursor binary linked to $bin_dir/cursor"
  elif [ -f "$HOME/.local/share/cursor/bin/cursor" ] && [ "$LOCAL_INSTALL" = true ]; then
    echo "Creating symbolic link for cursor binary..."
    mkdir -p "$bin_dir"
    ln -sf "$HOME/.local/share/cursor/bin/cursor" "$bin_dir/cursor"
    echo "cursor binary linked to $bin_dir/cursor"
  fi
}

# Function to copy install script
copy_install_script() {
  local bin_dir=$(get_bin_dir)
  local install_script="$bin_dir/install-$APP_DIR"
  echo "Copying install script to $install_script"
  mkdir -p "$bin_dir"
  cp "$SCRIPT_PATH" "$install_script"
  chmod +x "$install_script"
}

# Function to create uninstall script
create_uninstall_script() {
  local bin_dir=$(get_bin_dir)
  local install_base=$(get_install_base)
  local uninstall_script="$bin_dir/uninstall-$APP_DIR"
  echo "Creating uninstall script at $uninstall_script"
  mkdir -p "$bin_dir"
  
  cat << EOF > "$uninstall_script"
#!/bin/bash

LOCAL_INSTALL=${LOCAL_INSTALL}

# Function to get installation base directory
get_install_base() {
  if [ "\$LOCAL_INSTALL" = true ]; then
    echo "\$HOME/.local"
  else
    echo "/opt"
  fi
}

# Function to get bin directory
get_bin_dir() {
  if [ "\$LOCAL_INSTALL" = true ]; then
    echo "\$HOME/.local/bin"
  else
    echo "/usr/local/bin"
  fi
}

# Function to get applications directory
get_applications_dir() {
  if [ "\$LOCAL_INSTALL" = true ]; then
    echo "\$HOME/.local/share/applications"
  else
    echo "/usr/share/applications"
  fi
}

if [ "\$LOCAL_INSTALL" = false ] && [ "\$EUID" -ne 0 ]; then
  echo "Please run as root (with sudo) or use --local flag for user installation"
  exit 1
fi

echo "Uninstalling $APP_NAME..."

install_base=\$(get_install_base)
bin_dir=\$(get_bin_dir)

if [ -f "\$install_base/$APP_DIR/app_directories.txt" ]; then
  echo "Removing app-specific directories..."
  while read -r dir; do
    if [ "\$LOCAL_INSTALL" = true ]; then
      local_user_dir="\$HOME/.local/\${dir#/usr/}"
      [ -d "\$local_user_dir" ] && rm -rf "\$local_user_dir"
    else
      [ -d "\$dir" ] && rm -rf "\$dir"
    fi
  done < "\$install_base/$APP_DIR/app_directories.txt"
fi

if [ -f "\$install_base/$APP_DIR/installed_files.txt" ]; then
  echo "Removing individual files..."
  while read -r file; do
    if [ "\$LOCAL_INSTALL" = true ]; then
      local_user_file="\$HOME/.local/\${file#/usr/}"
      [ -f "\$local_user_file" ] && rm "\$local_user_file"
    else
      [ -f "/\$file" ] && rm "/\$file"
    fi
  done < "\$install_base/$APP_DIR/installed_files.txt"
fi

# Remove symbolic link for cursor binary
if [ -L "\$bin_dir/cursor" ]; then
  echo "Removing cursor binary symbolic link..."
  rm -f "\$bin_dir/cursor"
fi

# Remove install script
rm -f "\$bin_dir/install-$APP_DIR"

# Remove installation directory and tracking files
rm -rf "\$install_base/$APP_DIR"

if [ "\$LOCAL_INSTALL" = false ]; then
  update-desktop-database &>/dev/null || true
  update-mime-database /usr/share/mime &>/dev/null || true
fi

echo "$APP_NAME has been uninstalled."

# Remove the uninstall script last (self-deletion)
# Use a background process to ensure the script can complete before self-deletion
( sleep 0.1; rm -f "$uninstall_script" ) &
EOF
  chmod +x "$uninstall_script"
}

# Function to update desktop entry
update_desktop_entry() {
  local applications_dir=$(get_applications_dir)
  local bin_dir=$(get_bin_dir)
  
  for desktop_file in $DESKTOP_FILES; do
    local system_desktop_file="$applications_dir/$(basename "$desktop_file")"
    
    if [ -f "$system_desktop_file" ]; then
      echo "Adding uninstall and update actions to $system_desktop_file"
      
      # Add Actions line if it doesn't exist
      if ! grep -q "^Actions=" "$system_desktop_file"; then
        echo "Actions=Uninstall;Update;" >> "$system_desktop_file"
      else
        # Add Uninstall action if not present
        if ! grep -q "^Actions=.*Uninstall" "$system_desktop_file"; then
          sed -i '/^Actions=/ s/;*$/;Uninstall;/' "$system_desktop_file"
        fi
        # Add Update action if not present
        if ! grep -q "^Actions=.*Update" "$system_desktop_file"; then
          sed -i '/^Actions=/ s/;*$/;Update;/' "$system_desktop_file"
        fi
      fi

      # Add Uninstall action section if not present
      if ! grep -q "\[Desktop Action Uninstall\]" "$system_desktop_file"; then
        if [ "$LOCAL_INSTALL" = true ]; then
          cat << EOF >> "$system_desktop_file"

[Desktop Action Uninstall]
Name=Uninstall $APP_NAME
Exec=$bin_dir/uninstall-$APP_DIR
Icon=edit-delete
EOF
        else
          cat << EOF >> "$system_desktop_file"

[Desktop Action Uninstall]
Name=Uninstall $APP_NAME
Exec=pkexec $bin_dir/uninstall-$APP_DIR
Icon=edit-delete
EOF
        fi
      fi

      # Add Update action section if not present
      if ! grep -q "\[Desktop Action Update\]" "$system_desktop_file"; then
        if [ "$LOCAL_INSTALL" = true ]; then
          cat << EOF >> "$system_desktop_file"

[Desktop Action Update]
Name=Update $APP_NAME
Exec=$bin_dir/install-$APP_DIR
Icon=system-software-update
EOF
        else
          cat << EOF >> "$system_desktop_file"

[Desktop Action Update]
Name=Update $APP_NAME
Exec=pkexec $bin_dir/install-$APP_DIR
Icon=system-software-update
EOF
        fi
      fi
    fi
  done
}

# Main logic
# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      LOCAL_INSTALL=true
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [--local] [/path/to/your.AppImage]"
      exit 1
      ;;
    *)
      APPIMAGE_PATH="$1"
      shift
      ;;
  esac
done

# Store the original script path before changing directories
SCRIPT_PATH=$(readlink -f "$0")

check_root
detect_platform  # Detect platform before proceeding

if [ "$LOCAL_INSTALL" = true ]; then
  echo "Installing in local user directory ($HOME/.local)"
else
  echo "Installing in system directory (requires root privileges)"
fi

if [ -n "$APPIMAGE_PATH" ]; then
  [[ ! "$APPIMAGE_PATH" = /* ]] && APPIMAGE_PATH="$PWD/$APPIMAGE_PATH"
  echo "Using provided AppImage at: $APPIMAGE_PATH"
elif [ $# -eq 0 ]; then
  download_appimage
  echo "Using downloaded AppImage at: $APPIMAGE_PATH for platform: $PLATFORM"
else
  echo "Usage: $0 [--local] [/path/to/your.AppImage]"
  exit 1
fi

[ -f "$APPIMAGE_PATH" ] || { echo "Error: File '$APPIMAGE_PATH' does not exist"; exit 1; }
[[ "$APPIMAGE_PATH" != *".AppImage" ]] && echo "Warning: File doesn't have .AppImage extension. Continuing anyway..."

TEMP_DIR=$(mktemp -d)
echo "Creating temporary directory: $TEMP_DIR"
chmod +x "$APPIMAGE_PATH"
extract_appimage "$TEMP_DIR"

cd "$TEMP_DIR/squashfs-root"

DESKTOP_FILES=$(find . -name "*.desktop" -type f)
MAIN_DESKTOP_FILE=$(echo "$DESKTOP_FILES" | grep -v "url-handler\|uninstall" | head -1)

APP_NAME=$(grep -m 1 "^Name=" "$MAIN_DESKTOP_FILE" | cut -d= -f2)
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$MAIN_DESKTOP_FILE" .desktop)
[ -z "$APP_NAME" ] && APP_NAME=$(basename "$(readlink -f "$APPIMAGE_PATH")" .AppImage)

APP_DIR=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')
uninstall_existing

APP_SPECIFIC_DIRS=()
[ -d "usr/share/$APP_DIR" ] && APP_SPECIFIC_DIRS+=("/usr/share/$APP_DIR")
for dir in usr/share/*; do
  dir_name=$(basename "$dir")
  [[ "$dir_name" == *"$APP_DIR"* && "$dir_name" != "$APP_DIR" ]] && APP_SPECIFIC_DIRS+=("/usr/share/$dir_name")
done

install_app
copy_install_script
create_uninstall_script
update_desktop_entry

if [ "$LOCAL_INSTALL" = false ]; then
  echo "Updating desktop database..."
  update-desktop-database || true
fi

echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

bin_dir=$(get_bin_dir)
echo "Installation complete! You can now run $APP_NAME from your application menu or terminal."
echo "To uninstall, right-click on the application in your menu and select 'Uninstall'"
echo "To update, right-click on the application in your menu and select 'Update'"

if [ "$LOCAL_INSTALL" = true ]; then
  echo "Or run: $bin_dir/uninstall-$APP_DIR (to uninstall)"
  echo "Or run: $bin_dir/install-$APP_DIR (to update)"
  echo "Note: This is a local installation in your home directory."
else
  echo "Or run: sudo $bin_dir/uninstall-$APP_DIR (to uninstall)"
  echo "Or run: sudo $bin_dir/install-$APP_DIR (to update)"
fi
