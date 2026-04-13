#!/bin/bash

# Test script to verify sleep command works
echo "Testing sleep command..."

# Test the shutdown methods
echo "Testing pmset..."
if command -v pmset >/dev/null 2>&1; then
    echo "✓ pmset is available"
    echo "Note: pmset sleepnow would put the computer to sleep"
else
    echo "✗ pmset not available"
fi

echo "Testing osascript sleep..."
if osascript -e 'tell application "System Events" to sleep' 2>/dev/null; then
    echo "✓ osascript sleep works"
else
    echo "✗ osascript sleep failed"
fi

echo "Test complete!" 