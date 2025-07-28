# Daily Shutdown Scheduler for macOS

This project provides a complete solution for automatically shutting down your Mac at 5:45 PM daily using macOS's native `launchd` scheduler.

## Files Overview

- **`shutdown_script_interactive.sh`** - Interactive shutdown script that allows users to cancel shutdown
- **`com.user.dailyshutdown.plist.template`** - Template for launchd configuration (paths are replaced during installation)
- **`install.sh`** - Installation script to set up the shutdown schedule
- **`uninstall.sh`** - Script to remove the shutdown schedule
- **`README.md`** - This documentation file

## Installation

1. **Make the installation script executable:**
   ```bash
   chmod +x install.sh
   ```

2. **Run the installation script:**
   ```bash
   ./install.sh
   ```

The installation script will:
- Make the shutdown script executable
- Copy the plist file to your LaunchAgents directory
- Update the script path to match your actual directory
- Load the launchd job to start the schedule

## How It Works

The system uses macOS's `launchd` service to schedule the shutdown script to run daily at 5:45 PM. The interactive shutdown script:

- Logs all activities to `~/Library/Logs/daily_shutdown.log`
- Checks if a user session is active before shutting down
- Provides user warnings with notifications at 5, 3, and 1 minute before shutdown
- Allows users to cancel or confirm shutdown at the 1-minute mark
- Uses `sudo shutdown -h +0` to perform a clean shutdown

### Interactive Warning System

The script provides a 5-minute warning period with user interaction:
1. **5 minutes before**: Initial notification to save work
2. **3 minutes before**: Second warning notification
3. **1 minute before**: Final warning notification + dialog to proceed or cancel
4. **Shutdown**: Clean system shutdown (if user confirms)

## Verification

To verify the job is loaded and scheduled:
```bash
launchctl list | grep dailyshutdown
```

To view the shutdown logs:
```bash
tail -f ~/Library/Logs/daily_shutdown.log
```

## Uninstallation

To remove the shutdown schedule:
```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Manual Commands

### Check if job is loaded:
```bash
launchctl list | grep dailyshutdown
```

### Manually unload the job:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.dailyshutdown.plist
```

### Manually load the job:
```bash
launchctl load ~/Library/LaunchAgents/com.user.dailyshutdown.plist
```

## Log Files

The system creates several log files:
- `~/Library/Logs/daily_shutdown.log` - Main application log
- `~/Library/Logs/daily_shutdown_stdout.log` - Standard output
- `~/Library/Logs/daily_shutdown_stderr.log` - Standard error

## Security Considerations

- The script requires sudo privileges to shutdown the system
- You may be prompted for your password when the shutdown occurs
- The script only runs when a user session is detected

## Troubleshooting

1. **Job not running:** Check if the plist file exists in `~/Library/LaunchAgents/`
2. **Permission denied:** Ensure the shutdown script is executable
3. **Shutdown not working:** Check the log files for error messages
4. **Time zone issues:** The schedule uses your system's local time

## Interactive Features

The shutdown script provides a user-friendly interactive experience:

- **Warning Notifications**: Clear notifications at 5, 3, and 1 minute before shutdown
- **User Control**: At the 1-minute mark, users can choose to proceed or cancel the shutdown
- **Flexible Timing**: Users can extend their work time if needed
- **Safe Default**: If no user interaction occurs, the system will proceed with shutdown

## Portability

This project is designed to work on any macOS system:

- **No hardcoded paths**: Uses template-based configuration with automatic path detection
- **Universal installation**: Works regardless of username or installation directory
- **Self-contained**: All necessary files are included in the project
- **Easy deployment**: Can be copied to any Mac and installed immediately

## Customization

To change the shutdown time, edit the `com.user.dailyshutdown.plist.template` file:
- `Hour` - Set to 17 for 5 PM (24-hour format)
- `Minute` - Set to 45 for 45 minutes past the hour

To change the warning duration, modify the sleep times in `shutdown_script_interactive.sh`:
- Current: 5-minute total warning period
- Adjust the `sleep` commands to change timing

After making changes, reinstall the job:
```bash
./uninstall.sh
./install.sh
``` 