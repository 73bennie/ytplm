# Validate that URL file exists and is readable
validate_url_file() {
    local url_file="$1"
    
    [[ -f "$url_file" ]] || {
        log_error "File not found: $url_file"
        exit $EXIT_FILE_NOT_FOUND
    }
    
    [[ -r "$url_file" ]] || {
        log_error "File not readable: $url_file"
        exit $EXIT_FILE_NOT_FOUND
    }
}


