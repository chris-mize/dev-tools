#!/bin/bash

# Test script to verify shutdown command works
echo "Testing shutdown command..."

# Test the shutdown methods
echo "Testing pmset..."
if command -v pmset >/dev/null 2>&1; then
    echo "✓ pmset is available"
    echo "Note: pmset sleepnow would put the computer to sleep"
else
    echo "✗ pmset not available"
fi

echo "Testing shutdown command..."
if shutdown -h +0 2>/dev/null; then
    echo "✓ shutdown command works without sudo"
else
    echo "✗ shutdown command requires sudo"
fi

echo "Testing osascript shutdown..."
if osascript -e 'tell application "System Events" to shut down' 2>/dev/null; then
    echo "✓ osascript shutdown works"
else
    echo "✗ osascript shutdown failed"
fi

echo "Test complete!" 