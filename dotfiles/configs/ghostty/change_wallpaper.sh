#!/usr/bin/env bash

set -euo pipefail

START_MARKER="# dotfiles:start wallpaper"
END_MARKER="# dotfiles:end wallpaper"
TARGET_LUMA="${GHOSTTY_WALLPAPER_TARGET_LUMA:-55}"
MIN_OPACITY="0.15"
MAX_OPACITY="1.00"
SAMPLE_SIZE=32

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

measure_image_luma_stats() {
    local image_path="$1"
    local sample_bmp="$2"

    if ! command -v sips >/dev/null 2>&1; then
        printf 'Error: sips is required to measure wallpaper brightness.\n' >&2
        exit 1
    fi

    sips -s format bmp -z "$SAMPLE_SIZE" "$SAMPLE_SIZE" "$image_path" --out "$sample_bmp" >/dev/null

    od -An -t u1 -v "$sample_bmp" | awk '
        function le16u(offset) {
            return bytes[offset + 1] + (bytes[offset + 2] * 256)
        }

        function le32u(offset) {
            return bytes[offset + 1] + (bytes[offset + 2] * 256) + (bytes[offset + 3] * 65536) + (bytes[offset + 4] * 16777216)
        }

        function le32s(offset, value) {
            value = le32u(offset)
            if (value >= 2147483648) {
                value -= 4294967296
            }
            return value
        }

        function abs(value) {
            return value < 0 ? -value : value
        }

        {
            for (i = 1; i <= NF; i++) {
                bytes[++count] = $i
            }
        }
        END {
            if (count < 58) {
                exit 1
            }

            pixel_offset = le32u(10)
            width = le32s(18)
            height = abs(le32s(22))
            bits_per_pixel = le16u(28)

            if (pixel_offset < 0 || width <= 0 || height <= 0) {
                exit 1
            }

            if (bits_per_pixel != 24 && bits_per_pixel != 32) {
                exit 1
            }

            bytes_per_pixel = bits_per_pixel / 8
            row_stride = int(((width * bits_per_pixel) + 31) / 32) * 4

            if (count < pixel_offset + (row_stride * height)) {
                exit 1
            }

            for (y = 0; y < height; y++) {
                for (x = 0; x < width; x++) {
                    byte_index = pixel_offset + (y * row_stride) + (x * bytes_per_pixel)
                    blue = bytes[byte_index + 1]
                    green = bytes[byte_index + 2]
                    red = bytes[byte_index + 3]
                    luma = int(((299 * red) + (587 * green) + (114 * blue)) / 1000)
                    hist[luma]++
                    pixel_count++
                    sum += luma
                }
            }

            if (pixel_count <= 0) {
                exit 1
            }

            mean = int((sum / pixel_count) + 0.5)
            p95_index = int((pixel_count * 95) / 100)
            if ((pixel_count * 95) % 100 != 0) {
                p95_index++
            }

            seen = 0
            p95 = 255
            for (luma = 0; luma <= 255; luma++) {
                seen += hist[luma]
                if (seen >= p95_index) {
                    p95 = luma
                    break
                }
            }

            blended = int((((mean * 40) + (p95 * 60)) / 100) + 0.5)
            printf "%d %d %d\n", mean, p95, blended
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
sample_dir="$(mktemp -d "${TMPDIR:-/tmp}/ghostty-wallpaper-sample.XXXXXX")"
sample_bmp="$sample_dir/sample.bmp"
final_file="$(mktemp "$(dirname "$CONFIG_FILE")/.ghostty-config.local.XXXXXX")"
trap 'rm -f "$tmp_file" "$final_file"; rm -rf "$sample_dir"' EXIT

if ! LUMA_STATS="$(measure_image_luma_stats "$IMAGE_PATH" "$sample_bmp")"; then
    printf 'Error: failed to measure wallpaper brightness for %s\n' "$IMAGE_PATH" >&2
    exit 1
fi
read -r MEAN_LUMA P95_LUMA MEASURED_LUMA <<< "$LUMA_STATS"
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
echo "Measured luminance: mean $MEAN_LUMA/255; p95 $P95_LUMA/255; blended $MEASURED_LUMA/255; target $TARGET_LUMA/255; opacity $IMAGE_OPACITY"
echo "Press Cmd+Shift+, in Ghostty to reload config."
