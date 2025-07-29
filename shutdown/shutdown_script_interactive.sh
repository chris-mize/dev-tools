#!/bin/bash

# Interactive daily shutdown script for macOS
# This script will shutdown the computer at 5:45 PM daily with user interaction
#
# NOTIFICATION PERMISSIONS:
# Notification permissions are handled during installation.
# If notifications don't appear, re-run the install script or manually grant permissions:
# 1. Go to System Preferences > Notifications & Focus
# 2. Find "Terminal" or "iTerm" in the list
# 3. Enable notifications for the terminal application
# 4. Or install terminal-notifier: brew install terminal-notifier

# Set up logging
LOG_FILE="$HOME/Library/Logs/daily_shutdown.log"
LOG_DIR=$(dirname "$LOG_FILE")

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Notification function - simplified since permissions handled at install
send_notification() {
    local title="$1"
    local message="$2"
    
    # Try System Events notification first
    if osascript -e "tell application \"System Events\" to display notification \"$message\" with title \"$title\"" 2>/dev/null; then
        log_message "Sent notification: $title - $message"
        return 0
    fi
    
    # Fallback: Try using terminal-notifier if available
    if command -v terminal-notifier >/dev/null 2>&1; then
        if terminal-notifier -title "$title" -message "$message" -sound default 2>/dev/null; then
            log_message "Sent notification via terminal-notifier: $title - $message"
            return 0
        fi
    fi
    
    # Last resort: Write to system log
    logger -t "DailyShutdown" "$title: $message"
    log_message "Notification failed, logged to system log: $title - $message"
    return 1
}

# Dialog function to ask user - improved for background execution
ask_user() {
    local title="$1"
    local message="$2"
    local button1="$3"
    local button2="$4"
    
    # Use a more reliable dialog method for background execution
    osascript -e "tell application \"System Events\"
        activate
        set theResult to display dialog \"$message\" with title \"$title\" buttons {\"$button1\", \"$button2\"} default button \"$button1\" with icon caution
        return button returned of theResult
    end tell" 2>/dev/null
}

# Get current user
CURRENT_USER=$(who | grep console | awk '{print $1}' | head -1)

# Log the shutdown attempt
log_message "Interactive daily shutdown script started"

# Check if any user is logged in
if pgrep -f "loginwindow" > /dev/null && [ -n "$CURRENT_USER" ]; then
    log_message "User session detected for user: $CURRENT_USER"
    
    # Send initial warning notification
    send_notification "Daily Shutdown Warning" "Your computer will shutdown in 5 minutes. Please save your work."
    
    # Wait 2 minutes, then send second warning
    sleep 120
    send_notification "Daily Shutdown Warning" "Your computer will shutdown in 3 minutes. Save your work now!"
    
    # Wait 2 more minutes, then ask user
    sleep 120
    send_notification "Daily Shutdown Warning" "Your computer will shutdown in 1 minute. Final warning!"
    
    # Ask user if they want to proceed or cancel
    log_message "Asking user for confirmation"
    user_choice=$(ask_user "Daily Shutdown" "Your computer is scheduled to shutdown now." "Proceed" "Cancel")
    
    if [ "$user_choice" = "Cancel" ]; then
        log_message "User cancelled shutdown"
        send_notification "Shutdown Cancelled" "Daily shutdown has been cancelled. You can continue working."
        exit 0
    else
        log_message "User confirmed shutdown"
        
        
        # Use System Events shutdown method (preferred)
        log_message "Using System Events for shutdown"
        osascript -e 'tell application "System Events" to shut down'
        
        log_message "Shutdown command executed"
    fi
else
    log_message "No user session detected, skipping shutdown"
fi 