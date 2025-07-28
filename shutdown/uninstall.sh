#!/bin/bash

# Uninstall script for daily shutdown scheduler
# This script will remove the daily shutdown schedule

echo "Removing daily shutdown schedule..."

# Path to the plist file in LaunchAgents
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.dailyshutdown.plist"

# Unload the launchd job if it's loaded
if launchctl list | grep -q "dailyshutdown"; then
    launchctl unload "$PLIST_DEST"
    echo "✓ Unloaded launchd job"
else
    echo "✓ Job was not loaded"
fi

# Remove the plist file
if [ -f "$PLIST_DEST" ]; then
    rm "$PLIST_DEST"
    echo "✓ Removed plist file from LaunchAgents"
else
    echo "✓ Plist file was not found"
fi

echo ""
echo "Uninstallation complete! Daily shutdown has been disabled."
echo ""
echo "Note: Log files are still available at:"
echo "  $HOME/Library/Logs/daily_shutdown.log"
echo "  $HOME/Library/Logs/daily_shutdown_stdout.log"
echo "  $HOME/Library/Logs/daily_shutdown_stderr.log"
echo ""
echo "You can manually delete these log files if desired." 