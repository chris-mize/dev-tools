#!/bin/bash

# Installation script for daily shutdown scheduler
# This script will set up the daily shutdown at 5:45 PM

echo "Setting up daily shutdown at 5:45 PM..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check and request notification permissions
echo "Checking notification permissions..."
check_notification_permissions() {
    # Check if we can send notifications by attempting a test notification
    if osascript -e 'tell application "System Events" to display notification "Test" with title "Test"' 2>/dev/null; then
        echo "✓ Notification permissions confirmed"
        return 0
    else
        echo "⚠ Notification permissions not granted"
        echo "Requesting notification access..."
        
        # Try to request notification permissions by showing a dialog
        osascript -e 'tell application "System Events"
            activate
            display dialog "This shutdown script needs notification permissions to warn you about shutdowns. Please grant notification access when prompted." with title "Notification Permission Required" buttons {"OK"} default button "OK" with icon note
        end tell' 2>/dev/null
        
        # Try sending a test notification again
        if osascript -e 'tell application "System Events" to display notification "Test" with title "Test"' 2>/dev/null; then
            echo "✓ Notification permissions granted"
            return 0
        else
            echo "⚠ Notification permissions still not available"
            echo ""
            echo "IMPORTANT: You need to manually grant notification permissions:"
            echo "1. Go to System Preferences > Notifications & Focus"
            echo "2. Find your terminal app (Terminal, iTerm, etc.) in the list"
            echo "3. Enable notifications for the terminal application"
            echo "4. Or install terminal-notifier: brew install terminal-notifier"
            echo ""
            echo "The script will still work, but you won't see shutdown warnings."
            return 1
        fi
    fi
}

check_notification_permissions

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