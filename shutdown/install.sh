#!/bin/bash

# Installation script for daily shutdown scheduler
# This script will set up the daily shutdown at a specified time

# Function to parse time input
parse_time() {
    local time_input="$1"
    local hour minute
    
    # Remove any extra spaces and convert to lowercase
    time_input=$(echo "$time_input" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if input is in format "HH:MM AM/PM" or "H:MM AM/PM"
    if [[ $time_input =~ ^([0-9]{1,2}):([0-9]{2})[[:space:]]*(am|pm)$ ]]; then
        hour=${BASH_REMATCH[1]}
        minute=${BASH_REMATCH[2]}
        local period=${BASH_REMATCH[3]}
        
        # Convert to 24-hour format
        if [[ $period == "pm" && $hour != "12" ]]; then
            hour=$((hour + 12))
        elif [[ $period == "am" && $hour == "12" ]]; then
            hour=0
        fi
        
        echo "$hour:$minute"
        return 0
    else
        echo "Invalid time format. Please use format like '6:20 PM' or '18:20'" >&2
        return 1
    fi
}

# Function to display usage
show_usage() {
    echo "Usage: $0 [TIME]"
    echo ""
    echo "TIME: Shutdown time in format 'H:MM AM/PM' (e.g., '6:20 PM', '5:45 AM')"
    echo "      If not provided, will prompt for input"
    echo ""
    echo "Examples:"
    echo "  $0 '6:20 PM'    # Shutdown at 6:20 PM"
    echo "  $0 '5:45 AM'    # Shutdown at 5:45 AM"
    echo "  $0              # Interactive mode"
}

# Parse command line arguments
if [[ $# -eq 1 ]]; then
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_usage
        exit 0
    fi
    
    SHUTDOWN_TIME=$(parse_time "$1")
    if [[ $? -ne 0 ]]; then
        echo "Error: $SHUTDOWN_TIME"
        show_usage
        exit 1
    fi
else
    # Interactive mode - prompt for time
    echo "Daily Shutdown Scheduler Setup"
    echo "=============================="
    echo ""
    echo "Enter the time you want your computer to shutdown daily."
    echo "Format: H:MM AM/PM (e.g., 6:20 PM, 5:45 AM)"
    echo ""
    
    while true; do
        read -p "Shutdown time: " time_input
        SHUTDOWN_TIME=$(parse_time "$time_input")
        if [[ $? -eq 0 ]]; then
            break
        fi
        echo "Please try again with the correct format."
    done
fi

# Extract hour and minute from parsed time
IFS=':' read -r hour minute <<< "$SHUTDOWN_TIME"

echo "Setting up daily shutdown at $hour:$minute..."

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

# Replace placeholders with actual paths and time
sed -i '' "s|SCRIPT_PATH_PLACEHOLDER|$SCRIPT_DIR/shutdown_script_interactive.sh|g" "$PLIST_DEST"
sed -i '' "s|HOME_PATH_PLACEHOLDER|$HOME|g" "$PLIST_DEST"
sed -i '' "s|USER_PLACEHOLDER|$USER|g" "$PLIST_DEST"
sed -i '' "s|<integer>17</integer>|<integer>$hour</integer>|g" "$PLIST_DEST"
sed -i '' "s|<integer>40</integer>|<integer>$minute</integer>|g" "$PLIST_DEST"
echo "✓ Created and configured plist file with shutdown time $hour:$minute"

# Load the launchd job
launchctl load "$PLIST_DEST"
echo "✓ Loaded launchd job"

echo ""
echo "Installation complete! Your Mac will now shutdown daily at $hour:$minute with interactive warnings."
echo ""
echo "To check if the job is loaded:"
echo "  launchctl list | grep dailyshutdown"
echo ""
echo "To unload the job (disable shutdown):"
echo "  launchctl unload $PLIST_DEST"
echo ""
echo "To view logs:"
echo "  tail -f $HOME/Library/Logs/daily_shutdown.log" 