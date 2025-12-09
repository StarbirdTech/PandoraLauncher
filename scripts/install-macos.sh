#!/bin/bash
set -e

# Pandora Launcher - macOS Install Script
# Builds and installs as a proper .app bundle

APP_NAME="Pandora Launcher"
BUNDLE_ID="com.moulberry.pandora-launcher"
VERSION="0.1.0"
INSTALL_DIR="/Applications"
APP_PATH="$INSTALL_DIR/$APP_NAME.app"

echo "Building Pandora Launcher for macOS..."

# Ensure we're in the project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Build release binary
echo "Compiling release binary..."
cargo build --release

# Create temporary directory for icon conversion
ICON_TEMP=$(mktemp -d)
ICONSET="$ICON_TEMP/AppIcon.iconset"
mkdir -p "$ICONSET"

# Convert SVG to multiple PNG sizes for iconset
echo "Generating app icon..."
SVG_PATH="$PROJECT_ROOT/assets/icons/pandora.svg"

if command -v magick &> /dev/null; then
    CONVERT_CMD="magick"
elif command -v convert &> /dev/null; then
    CONVERT_CMD="convert"
else
    echo "Error: ImageMagick not found. Install with: brew install imagemagick"
    exit 1
fi

$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 16x16 "$ICONSET/icon_16x16.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 32x32 "$ICONSET/icon_16x16@2x.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 32x32 "$ICONSET/icon_32x32.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 64x64 "$ICONSET/icon_32x32@2x.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 128x128 "$ICONSET/icon_128x128.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 256x256 "$ICONSET/icon_128x128@2x.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 256x256 "$ICONSET/icon_256x256.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 512x512 "$ICONSET/icon_256x256@2x.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 512x512 "$ICONSET/icon_512x512.png"
$CONVERT_CMD -background none -density 384 "$SVG_PATH" -resize 1024x1024 "$ICONSET/icon_512x512@2x.png"

# Create .icns file
iconutil -c icns "$ICONSET" -o "$ICON_TEMP/AppIcon.icns"

# Remove old app bundle if it exists
if [ -d "$APP_PATH" ]; then
    echo "Removing existing installation..."
    rm -rf "$APP_PATH"
fi

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy binary
cp "$PROJECT_ROOT/target/release/pandora_launcher" "$APP_PATH/Contents/MacOS/PandoraLauncher"

# Copy icon
cp "$ICON_TEMP/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>PandoraLauncher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Cleanup temp files
rm -rf "$ICON_TEMP"

# Register with Launch Services
echo "Registering with macOS..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH"

# Touch to update Spotlight
touch "$APP_PATH"

echo ""
echo "Installation complete!"
echo ""
echo "Pandora Launcher installed to: $APP_PATH"
echo ""
echo "To add CLI commands, add these lines to your ~/.zshrc:"
echo "  alias pandora='open -a \"Pandora Launcher\"'"
echo "  alias mc='pandora'"
echo ""
echo "You can now:"
echo "  - Find it in Spotlight (Cmd+Space, type 'Pandora')"
echo "  - Drag it to your Dock from Applications"
echo "  - Launch with: open -a 'Pandora Launcher'"