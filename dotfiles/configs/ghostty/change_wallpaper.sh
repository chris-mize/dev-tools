#!/usr/bin/env bash

set -euo pipefail

START_MARKER="# dotfiles:start wallpaper"
END_MARKER="# dotfiles:end wallpaper"
TARGET_LUMA="${GHOSTTY_WALLPAPER_TARGET_LUMA:-55}"
MIN_OPACITY="0.15"
MAX_OPACITY="1.00"

validate_target_luma() {
    if ! [[ "$TARGET_LUMA" =~ ^[0-9]+$ ]] || (( TARGET_LUMA < 1 || TARGET_LUMA > 255 )); then
        printf 'Error: GHOSTTY_WALLPAPER_TARGET_LUMA must be an integer from 1 to 255.\n' >&2
        exit 1
    fi
}

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

measure_image_luma() {
    local image_path="$1"
    local sample_bmp="$2"

    if ! command -v sips >/dev/null 2>&1; then
        printf 'Error: sips is required to measure wallpaper brightness.\n' >&2
        exit 1
    fi

    sips -s format bmp -z 1 1 "$image_path" --out "$sample_bmp" >/dev/null

    od -An -t u1 -v "$sample_bmp" | awk '
        {
            for (i = 1; i <= NF; i++) {
                bytes[++count] = $i
            }
        }
        END {
            if (count < 58) {
                exit 1
            }

            pixel_offset = bytes[11] + (bytes[12] * 256) + (bytes[13] * 65536) + (bytes[14] * 16777216)
            bits_per_pixel = bytes[29] + (bytes[30] * 256)

            if (pixel_offset < 0 || count < pixel_offset + 3) {
                exit 1
            }

            if (bits_per_pixel != 24 && bits_per_pixel != 32) {
                exit 1
            }

            blue = bytes[pixel_offset + 1]
            green = bytes[pixel_offset + 2]
            red = bytes[pixel_offset + 3]
            printf "%d\n", ((299 * red) + (587 * green) + (114 * blue)) / 1000
        }
    '
}

calculate_opacity() {
    local measured_luma="$1"

    awk -v measured="$measured_luma" -v target="$TARGET_LUMA" -v min="$MIN_OPACITY" -v max="$MAX_OPACITY" '
        BEGIN {
            if (measured <= 0) {
                opacity = max
            } else {
                opacity = target / measured
            }

            if (opacity < min) {
                opacity = min
            }
            if (opacity > max) {
                opacity = max
            }

            printf "%.2f\n", opacity
        }
    '
}

validate_target_luma

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
sample_bmp="$(mktemp "${TMPDIR:-/tmp}/ghostty-wallpaper-sample.XXXXXX")"
final_file="$(mktemp "$(dirname "$CONFIG_FILE")/.ghostty-config.local.XXXXXX")"
trap 'rm -f "$tmp_file" "$sample_bmp" "$final_file"' EXIT

if ! MEASURED_LUMA="$(measure_image_luma "$IMAGE_PATH" "$sample_bmp")"; then
    printf 'Error: failed to measure wallpaper brightness for %s\n' "$IMAGE_PATH" >&2
    exit 1
fi
IMAGE_OPACITY="$(calculate_opacity "$MEASURED_LUMA")"

awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "$CONFIG_FILE" > "$tmp_file"

{
    cat "$tmp_file"
    [[ -s "$tmp_file" ]] && printf '\n'
    printf '%s\n' "$START_MARKER"
    printf 'background = 000000\n'
    printf 'background-image = "%s"\n' "$ESCAPED_IMAGE_PATH"
    printf 'background-image-opacity = %s\n' "$IMAGE_OPACITY"
    printf 'background-image-fit = cover\n'
    printf '%s\n' "$END_MARKER"
} > "$final_file"

mv "$final_file" "$CONFIG_FILE"

echo "✅ Ghostty background updated to: $IMAGE_PATH"
echo "Measured luminance: $MEASURED_LUMA/255; target: $TARGET_LUMA/255; opacity: $IMAGE_OPACITY"
echo "Press Cmd+Shift+, in Ghostty to reload config."
