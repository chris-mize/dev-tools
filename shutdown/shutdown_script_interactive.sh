#!/bin/bash

# Interactive daily shutdown script for macOS
# This script will shutdown the computer at 5:45 PM daily with user interaction

# Set up logging
LOG_FILE="$HOME/Library/Logs/daily_shutdown.log"
LOG_DIR=$(dirname "$LOG_FILE")

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Notification function
send_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Dialog function to ask user
ask_user() {
    local title="$1"
    local message="$2"
    local button1="$3"
    local button2="$4"
    
    osascript -e "tell application \"System Events\"
        activate
        set theResult to display dialog \"$message\" with title \"$title\" buttons {\"$button1\", \"$button2\"} default button \"$button1\" with icon caution
        return button returned of theResult
    end tell"
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
    log_message "Sent initial warning notification"
    
    # Wait 2 minutes, then send second warning
    sleep 120
    send_notification "Daily Shutdown Warning" "Your computer will shutdown in 3 minutes. Save your work now!"
    log_message "Sent second warning notification"
    
    # Wait 2 more minutes, then ask user
    sleep 120
    send_notification "Daily Shutdown Warning" "Your computer will shutdown in 1 minute. Final warning!"
    log_message "Sent final warning notification"
    
    # Ask user if they want to proceed or cancel
    log_message "Asking user for confirmation"
    user_choice=$(ask_user "Daily Shutdown" "Your computer is scheduled to shutdown in 1 minute. Do you want to proceed or cancel?" "Proceed" "Cancel")
    
    if [ "$user_choice" = "Cancel" ]; then
        log_message "User cancelled shutdown"
        send_notification "Shutdown Cancelled" "Daily shutdown has been cancelled. You can continue working."
        exit 0
    else
        log_message "User confirmed shutdown"
        send_notification "Shutdown Confirmed" "Shutdown will proceed in 1 minute. Save your work now!"
        
        # Wait 1 minute, then shutdown
        sleep 60
        log_message "Initiating shutdown after user confirmation"
        
        # Shutdown the computer
        sudo shutdown -h +0
        
        log_message "Shutdown command executed"
    fi
else
    log_message "No user session detected, skipping shutdown"
fi 