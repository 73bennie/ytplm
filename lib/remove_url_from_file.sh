# Remove processed URL from file
remove_url_from_file() {
    local url="$1"
    local url_file="$2"
    local temp_file="${url_file}.tmp"

    if [[ -s "$url_file" ]]; then
        # Normalize URL
        local norm_url
        norm_url=$(echo "$url" | tr -d '\r' | xargs)

        # Filter the file line by line
        awk -v target="$norm_url" '
            {
                line = $0
                gsub(/\r/, "", line)
                sub(/^[ \t]+/, "", line)
                sub(/[ \t]+$/, "", line)
                if (line != target) print $0
            }
        ' "$url_file" > "$temp_file" && mv "$temp_file" "$url_file"
    fi
}


