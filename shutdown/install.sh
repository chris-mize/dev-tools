#!/bin/bash

# Installation script for daily shutdown scheduler
# This script will set up the daily shutdown at 5:45 PM

echo "Setting up daily shutdown at 5:45 PM..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make the shutdown script executable
chmod +x "$SCRIPT_DIR/shutdown_script_interactive.sh"
echo "✓ Made shutdown script executable"

# Copy the plist template and replace placeholders with actual paths
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.dailyshutdown.plist"
cp "$SCRIPT_DIR/com.user.dailyshutdown.plist.template" "$PLIST_DEST"

# Replace placeholders with actual paths
sed -i '' "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR/shutdown_script_interactive.sh|g" "$PLIST_DEST"
sed -i '' "s|HOME_PATH_PLACEHOLDER|$HOME|g" "$PLIST_DEST"
sed -i '' "s|USER_PLACEHOLDER|$USER|g" "$PLIST_DEST"
echo "✓ Created and configured plist file"

# Load the launchd job
launchctl load "$PLIST_DEST"
echo "✓ Loaded launchd job"

echo ""
echo "Installation complete! Your Mac will now shutdown daily at 5:45 PM with interactive warnings."
echo ""
echo "To check if the job is loaded:"
echo "  launchctl list | grep dailyshutdown"
echo ""
echo "To unload the job (disable shutdown):"
echo "  launchctl unload $PLIST_DEST"
echo ""
echo "To view logs:"
echo "  tail -f $HOME/Library/Logs/daily_shutdown.log" 