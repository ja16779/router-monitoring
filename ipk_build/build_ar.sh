#!/bin/bash
# Manually build an ar archive (.ipk) from component files
# .ipk format: ar archive containing debian-binary, control.tar.gz, data.tar.gz

OUTPUT="$1"
BUILD_DIR="$(dirname "$0")"

# ar global header
printf '!<arch>\n' > "$OUTPUT"

# Function to add a file to the ar archive
add_ar_member() {
    local filepath="$1"
    local membername="$2"
    local filesize=$(wc -c < "$filepath" | tr -d ' ')
    local timestamp=$(date +%s)

    # ar header: 60 bytes total
    # name(16) + timestamp(12) + uid(6) + gid(6) + mode(8) + size(10) + magic(2)
    printf '%-16s%-12s%-6s%-6s%-8s%-10s\x60\x0a' \
        "${membername}" \
        "${timestamp}" \
        "0" \
        "0" \
        "100644" \
        "${filesize}" >> "$OUTPUT"

    # File data
    cat "$filepath" >> "$OUTPUT"

    # Pad to even byte boundary
    if [ $((filesize % 2)) -ne 0 ]; then
        printf '\n' >> "$OUTPUT"
    fi
}

add_ar_member "$BUILD_DIR/debian-binary" "debian-binary"
add_ar_member "$BUILD_DIR/control.tar.gz" "control.tar.gz"
add_ar_member "$BUILD_DIR/data.tar.gz" "data.tar.gz"

echo "Built: $OUTPUT ($(wc -c < "$OUTPUT" | tr -d ' ') bytes)"
