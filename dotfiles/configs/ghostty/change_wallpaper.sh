#!/usr/bin/env bash

set -euo pipefail

START_MARKER="# dotfiles:start wallpaper"
END_MARKER="# dotfiles:end wallpaper"

validate_managed_block_state() {
    local target="$1"

    if [[ ! -e "$target" ]]; then
        return
    fi

    if ! awk -v start="$START_MARKER" -v end="$END_MARKER" '
        BEGIN { state = 0; starts = 0; ends = 0 }
        $0 == start {
            if (state == 1) exit 1
            state = 1
            starts++
            next
        }
        $0 == end {
            if (state == 0) exit 1
            state = 0
            ends++
            next
        }
        END {
            if (state != 0) exit 1
            if (starts != ends) exit 1
            if (starts > 1) exit 1
        }
    ' "$target"; then
        printf 'Error: invalid wallpaper block markers in %s\n' "$target" >&2
        exit 1
    fi
}

# 1. Open native macOS file picker to select an image
# Filters for common image types
IMAGE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "Select Ghostty Background:" of type {"public.image"})' 2>/dev/null)

# Exit if user hits Cancel
if [ -z "$IMAGE_PATH" ]; then
    echo "No file selected. Exiting."
    exit 1
fi

case "$IMAGE_PATH" in
    *$'\n'*|*$'\r'*)
        echo "Selected path contains a newline, which Ghostty config cannot represent safely."
        exit 1
        ;;
esac

CONFIG_FILE="$HOME/.config/ghostty/config.local"

# 2. Check if config exists, create it if not
mkdir -p "$(dirname "$CONFIG_FILE")"
touch "$CONFIG_FILE"
validate_managed_block_state "$CONFIG_FILE"

ESCAPED_IMAGE_PATH="${IMAGE_PATH//\\/\\\\}"
ESCAPED_IMAGE_PATH="${ESCAPED_IMAGE_PATH//\"/\\\"}"

tmp_file="$(mktemp)"
final_file="$(mktemp "$(dirname "$CONFIG_FILE")/.ghostty-config.local.XXXXXX")"
trap 'rm -f "$tmp_file" "$final_file"' EXIT

awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "$CONFIG_FILE" > "$tmp_file"

{
    cat "$tmp_file"
    [[ -s "$tmp_file" ]] && printf '\n'
    printf '%s\n' "$START_MARKER"
    printf 'background-image = "%s"\n' "$ESCAPED_IMAGE_PATH"
    printf 'background-image-opacity = 0.6\n'
    printf 'background-image-fit = cover\n'
    printf '%s\n' "$END_MARKER"
} > "$final_file"

mv "$final_file" "$CONFIG_FILE"

echo "✅ Ghostty background updated to: $IMAGE_PATH"
echo "Press Cmd+Shift+, in Ghostty to reload config."
