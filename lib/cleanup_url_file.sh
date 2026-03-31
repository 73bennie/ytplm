#Clean up empty URL file
cleanup_url_file() {
    local url_file="$1"
    
    if [[ -f "$url_file" && ! -s "$url_file" ]]; then
        log_info "All playlists processed. Removing empty file: $url_file"
        rm -f "$url_file"
    fi
}


