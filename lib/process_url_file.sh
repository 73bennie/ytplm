# Process URLs from file
process_url_file() {
    local url_file="$1"
    local url
    validate_url_file "$url_file"
    if [[ ! -s "$url_file" ]]; then
        log_info "$RED" "Playlist URL file is empty."
echo
        exit 0
    fi

    # Count the number of non-empty, non-comment lines
    local total
    total=$(grep -v '^[[:space:]]*$' "$url_file" | grep -v '^[[:space:]]*#' | wc -l)
    log_info "$BLUE" "$total playlist(s) to process."

    local count=0
    while IFS= read -r url || [[ -n "$url" ]]; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        url=$(echo "$url" | xargs)
        [[ -n "$url" ]] || continue

        count=$((count + 1))
        log_info "$BLUE" "Processing playlist $count of $total"
        echo

        if process_url "$url"; then
            remove_url_from_file "$url" "$url_file"
            echo ""
            log_info "$GREEN" "Successfully processed playlist"
sleep 3
        else
            log_error "$RED" "Failed to process url (keeping in file)"
        fi
        echo
    done < "$url_file"
}


