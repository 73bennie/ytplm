#!/usr/bin/env bash

# Input validation functions for security

# Validate that a string contains only safe characters for filenames
validate_filename() {
    local input="$1"
    local max_length="${2:-255}"
    
    # Check length
    if [[ ${#input} -gt $max_length ]]; then
        return 1
    fi
    
    # Check for dangerous characters using case statement (more compatible)
    case "$input" in
        *"<"*|*">"*|*":"*|*"/"*|*"\\"*|*"|"*|*"?"*|*"*"*) 
            return 1
            ;;
    esac
    
    # Check for control characters
    case "$input" in
        *$'\x00'*|*$'\x01'*|*$'\x02'*|*$'\x03'*|*$'\x04'*|*$'\x05'*|*$'\x06'*|*$'\x07'*|*$'\x08'*|*$'\x09'*|*$'\x0A'*|*$'\x0B'*|*$'\x0C'*|*$'\x0D'*|*$'\x0E'*|*$'\x0F'*|*$'\x10'*|*$'\x11'*|*$'\x12'*|*$'\x13'*|*$'\x14'*|*$'\x15'*|*$'\x16'*|*$'\x17'*|*$'\x18'*|*$'\x19'*|*$'\x1A'*|*$'\x1B'*|*$'\x1C'*|*$'\x1D'*|*$'\x1E'*|*$'\x1F'*|*$'\x7F'*)
            return 1
            ;;
    esac
    
    return 0
}

# Validate playlist ID format
validate_playlist_id() {
    local playlist_id="$1"
    
    # YouTube playlist IDs are typically 34 characters and contain letters, numbers, and hyphens
    case "$playlist_id" in
        [A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-]*)
            # Check length (10-34 characters)
            if [[ ${#playlist_id} -ge 10 && ${#playlist_id} -le 34 ]]; then
                return 0
            fi
            ;;
    esac
    return 1
}

# Validate YouTube video ID format
validate_video_id() {
    local video_id="$1"
    
    # YouTube video IDs are exactly 11 characters and contain letters, numbers, and hyphens
    case "$video_id" in
        [A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-][A-Za-z0-9_-])
            return 0
            ;;
    esac
    return 1
}

# Validate URL format
validate_url() {
    local url="$1"
    
    # Basic URL validation for YouTube URLs using case statement
    case "$url" in
        http://www.youtube.com/*|https://www.youtube.com/*|http://youtube.com/*|https://youtube.com/*|http://music.youtube.com/*|https://music.youtube.com/*|http://youtu.be/*|https://youtu.be/*)
            return 0
            ;;
    esac
    return 1
}

# Validate playlist input (URL or playlist ID)
validate_playlist_input() {
    local input="$1"
    
    # If it's a valid URL, accept it
    if validate_url "$input"; then
        return 0
    fi
    
    # If it's a valid playlist ID, accept it
    if validate_playlist_id "$input"; then
        return 0
    fi
    
    return 1
}

# Sanitize user input for display (remove control characters)
sanitize_display() {
    local input="$1"
    echo "$input" | tr -d '\000-\037\177-\377'
}

# Validate and sanitize artist/album/title strings
validate_metadata_string() {
    local input="$1"
    local max_length="${2:-255}"
    
    # Check length
    if [[ ${#input} -gt $max_length ]]; then
        return 1
    fi
    
    # Remove null bytes
    input=$(echo "$input" | tr -d '\0')
    
    # Check for excessive whitespace using case statement
    case "$input" in
        *[![:space:]]*) 
            echo "$input"
            return 0
            ;;
        *) 
            return 1
            ;;
    esac
}

# Log security events
log_security_event() {
    local event_type="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] SECURITY [$event_type]: $message" >> "${LOG_FILE:-/dev/stderr}"
} 