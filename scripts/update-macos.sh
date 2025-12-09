#!/bin/bash
set -e

# Pandora Launcher - macOS Update Script
# Pulls latest changes and reinstalls if there are updates

APP_NAME="Pandora Launcher"
APP_PATH="/Applications/$APP_NAME.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Fetch both remotes
git fetch upstream --quiet 2>/dev/null || true
git fetch origin --quiet

# Check if we're behind upstream or origin
LOCAL=$(git rev-parse HEAD)
UPSTREAM=$(git rev-parse upstream/master 2>/dev/null || echo "$LOCAL")
ORIGIN=$(git rev-parse origin/personal/macos 2>/dev/null || echo "$LOCAL")

# Check for upstream changes to merge
if [ "$LOCAL" != "$UPSTREAM" ]; then
    echo "Pandora: New upstream changes available"
    echo "  Run 'cd $PROJECT_ROOT && git merge upstream/master' to update"
fi

# Check if local is behind origin (e.g., changes from another machine)
if [ "$LOCAL" != "$ORIGIN" ]; then
    echo "Pandora: Pulling latest from origin..."
    git pull origin personal/macos --quiet
fi

# Check if rebuild is needed (compare binary mtime vs git HEAD time)
NEEDS_REBUILD=false

if [ ! -f "$APP_PATH/Contents/MacOS/PandoraLauncher" ]; then
    NEEDS_REBUILD=true
elif [ ! -f "$PROJECT_ROOT/target/release/pandora_launcher" ]; then
    NEEDS_REBUILD=true
else
    # Check if any source files are newer than the binary
    BINARY_TIME=$(stat -f %m "$APP_PATH/Contents/MacOS/PandoraLauncher")
    NEWEST_SOURCE=$(find "$PROJECT_ROOT/crates" -name "*.rs" -newer "$APP_PATH/Contents/MacOS/PandoraLauncher" 2>/dev/null | head -1)

    if [ -n "$NEWEST_SOURCE" ]; then
        NEEDS_REBUILD=true
    fi
fi

if [ "$NEEDS_REBUILD" = true ]; then
    echo "Pandora: Rebuilding..."
    cargo build --release --quiet
    cp "$PROJECT_ROOT/target/release/pandora_launcher" "$APP_PATH/Contents/MacOS/PandoraLauncher"
    touch "$APP_PATH"
    echo "Pandora: Updated to $(git rev-parse --short HEAD)"
else
    echo "Pandora: Up to date"
fi
