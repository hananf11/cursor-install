#!/bin/bash

# install.sh - Script to download, extract, and install an AppImage
# Usage: ./install.sh [/path/to/your.AppImage]

set -e  # Exit on any error

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

# Function to check if the script is run as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (with sudo)"
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
  local uninstall_script="/usr/local/bin/uninstall-$APP_DIR"
  if [ -x "$uninstall_script" ]; then
    echo "Existing installation found. Uninstalling..."
    "$uninstall_script"
  fi
}

# Function to install the application
install_app() {
  mkdir -p "/opt/$APP_DIR"

  echo "Creating file tracking list for easy uninstallation..."
  local exclude_pattern=""
  for dir in "${APP_SPECIFIC_DIRS[@]}"; do
    local rel_dir="${dir#/usr/}"
    exclude_pattern="${exclude_pattern:+$exclude_pattern|}$rel_dir"
  done

  if [ -n "$exclude_pattern" ]; then
    find usr -type f | grep -v -E "$exclude_pattern" > "/opt/$APP_DIR/installed_files.txt"
  else
    find usr -type f > "/opt/$APP_DIR/installed_files.txt"
  fi

  if [ ${#APP_SPECIFIC_DIRS[@]} -gt 0 ]; then
    printf "%s\n" "${APP_SPECIFIC_DIRS[@]}" > "/opt/$APP_DIR/app_directories.txt"
  fi

  echo "Copying files to system directories..."
  cp -r usr/* /usr/
}

# Function to create uninstall script
create_uninstall_script() {
  local uninstall_script="/usr/local/bin/uninstall-$APP_DIR"
  echo "Creating uninstall script at $uninstall_script"
  cat << EOF > "$uninstall_script"
#!/bin/bash

if [ "\$EUID" -ne 0 ]; then
  echo "Please run as root (with sudo)"
  exit 1
fi

echo "Uninstalling $APP_NAME..."

if [ -f "/opt/$APP_DIR/app_directories.txt" ]; then
  echo "Removing app-specific directories..."
  while read -r dir; do
    [ -d "\$dir" ] && rm -rf "\$dir"
  done < "/opt/$APP_DIR/app_directories.txt"
fi

if [ -f "/opt/$APP_DIR/installed_files.txt" ]; then
  echo "Removing individual files..."
  while read -r file; do
    [ -f "/\$file" ] && rm "/\$file"
  done < "/opt/$APP_DIR/installed_files.txt"
fi

rm -f "$uninstall_script"
rm -rf "/opt/$APP_DIR"
update-desktop-database &>/dev/null || true
update-mime-database /usr/share/mime &>/dev/null || true

echo "$APP_NAME has been uninstalled."
EOF
  chmod +x "$uninstall_script"
}

# Function to update desktop entry
update_desktop_entry() {
  for desktop_file in $DESKTOP_FILES; do
    local system_desktop_file="/usr/share/applications/$(basename "$desktop_file")"
    
    if [ -f "$system_desktop_file" ]; then
      echo "Adding uninstall action to $system_desktop_file"
      
      if grep -q "^Actions=" "$system_desktop_file"; then
        grep -q "^Actions=.*Uninstall" "$system_desktop_file" || \
          sed -i '/^Actions=/ s/;*$/;Uninstall;/' "$system_desktop_file"
      else
        echo "Actions=Uninstall;" >> "$system_desktop_file"
      fi

      if ! grep -q "\[Desktop Action Uninstall\]" "$system_desktop_file"; then
        cat << EOF >> "$system_desktop_file"

[Desktop Action Uninstall]
Name=Uninstall $APP_NAME
Exec=pkexec $UNINSTALL_SCRIPT
Icon=edit-delete
EOF
      fi
    fi
  done
}

# Main logic
check_root
detect_platform  # Detect platform before proceeding

if [ $# -eq 1 ]; then
  APPIMAGE_PATH="$1"
  [[ ! "$APPIMAGE_PATH" = /* ]] && APPIMAGE_PATH="$PWD/$APPIMAGE_PATH"
  echo "Using provided AppImage at: $APPIMAGE_PATH"
elif [ $# -eq 0 ]; then
  download_appimage
  echo "Using downloaded AppImage at: $APPIMAGE_PATH for platform: $PLATFORM"
else
  echo "Usage: $0 [/path/to/your.AppImage]"
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
create_uninstall_script
update_desktop_entry

echo "Updating desktop database..."
update-desktop-database || true

echo "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

echo "Installation complete! You can now run $APP_NAME from your application menu or terminal."
echo "To uninstall, right-click on the application in your menu and select 'Uninstall'"
echo "Or run: sudo /usr/local/bin/uninstall-$APP_DIR"
