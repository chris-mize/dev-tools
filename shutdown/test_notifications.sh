#!/bin/bash

# Test script to verify notifications work
echo "Testing notification system..."

# Test the notification function
send_notification() {
    local title="$1"
    local message="$2"
    
    echo "Sending notification: $title - $message"
    
    # Try multiple notification methods
    # Method 1: osascript with explicit app targeting
    osascript -e "tell application \"System Events\" to display notification \"$message\" with title \"$title\"" 2>/dev/null
    
    # Method 2: Alternative notification method
    if ! osascript -e "tell application \"System Events\" to display notification \"$message\" with title \"$title\"" 2>/dev/null; then
        # Fallback: Use terminal notification if available
        if command -v terminal-notifier >/dev/null 2>&1; then
            terminal-notifier -title "$title" -message "$message" -sound default
        else
            # Last resort: Write to system log
            logger -t "DailyShutdown" "$title: $message"
        fi
    fi
}

# Test notifications
send_notification "Test Notification" "This is a test notification from the shutdown script"
echo "Test notification sent. Did you see it?"

# Test dialog
echo "Testing dialog system..."
user_choice=$(osascript -e "tell application \"System Events\"
    activate
    set theResult to display dialog \"This is a test dialog. Click OK to continue.\" with title \"Test Dialog\" buttons {\"OK\", \"Cancel\"} default button \"OK\"
    return button returned of theResult
end tell" 2>/dev/null)

echo "Dialog result: $user_choice"

echo "Test complete!" 