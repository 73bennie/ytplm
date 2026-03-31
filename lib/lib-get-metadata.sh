# UTILITY FUNCTIONS
 
#Detect playlist or track url
is_playlist_url() {
    local url="$1"
    
    # Check if it contains list= (full URL)
    if [[ "$url" == *"list="* ]]; then
        return 0
    fi
    
    # Check if it's a playlist ID (alphanumeric string, typically 34 characters)
    if [[ "$url" =~ ^[A-Za-z0-9_-]{20,}$ ]]; then
        return 0
    fi
    
    return 1
}

process_url() {
    local url="$1"
    if is_playlist_url "$url"; then
        process_playlist "$url"
    else
        # Single track URL
        # Extract track id from URL query param v=
        local track_id
        track_id=$(echo "$url" | grep -oP '(?<=v=)[^&]+') || {
            log_error "Invalid track URL: $url"
            return 1
        }

        # Fallback check if track_id is empty
        if [[ -z "$track_id" ]]; then
            log_error "Could not extract track ID from URL: $url"
            return 1
        fi
        echo ""

        # Use dummy playlist ID for single tracks or use track_id as playlist_id
        local dummy_playlist_id="single_track_$track_id"
        process_track "$track_id" "$dummy_playlist_id" 1 1 1
    fi
}

# URL AND METADATA PROCESSING
# ===========================

# Normalize URL or playlist ID to full YouTube Music URL
normalize_playlist_url() {
    local input="$1"
    local playlist_id
    
    # If it's already a full URL, return as is
    if [[ "$input" == *"music.youtube.com"* ]] && [[ "$input" == *"list="* ]]; then
        echo "$input"
        return 0
    fi
    
    # If it's just a playlist ID (alphanumeric string, typically 34 characters)
    if [[ "$input" =~ ^[A-Za-z0-9_-]{20,}$ ]]; then
        echo "https://music.youtube.com/playlist?list=$input"
        return 0
    fi
    
    # If it's a YouTube URL with playlist ID, convert to music.youtube.com
    if [[ "$input" == *"youtube.com"* ]] && [[ "$input" == *"list="* ]]; then
        playlist_id=$(echo "$input" | grep -oP 'list=\K[^&]+')
        if [[ -n "$playlist_id" ]]; then
            echo "https://music.youtube.com/playlist?list=$playlist_id"
            return 0
        fi
    fi
    
    log_error "Invalid playlist URL or ID format: $input"
    return 1
}

# Extract playlist ID from YouTube URL
extract_playlist_id() {
    local input="$1"
    local playlist_id
    
    # If it's already just a playlist ID (alphanumeric string, typically 34 characters)
    if [[ "$input" =~ ^[A-Za-z0-9_-]{20,}$ ]]; then
        echo "$input"
        return 0
    fi
    
    # If it's a full URL, extract the playlist ID
    if [[ "$input" == *"list="* ]]; then
        playlist_id=$(echo "$input" | grep -oP 'list=\K[^&]+') || {
            log_error "Invalid playlist URL format: $input"
            return 1
        }
        
        [[ -n "$playlist_id" ]] || {
            log_error "Could not extract playlist ID from: $input"
            return 1
        }
        
        echo "$playlist_id"
        return 0
    fi
    
    log_error "Invalid playlist URL or ID format: $input"
    return 1
}

# Fetch playlist metadata using yt-dlp
fetch_playlist_metadata() {
    local url="$1"
    local metadata
    
    log_debug "Fetching playlist metadata for: $url"
    
    metadata=$(yt-dlp --flat-playlist --dump-single-json "$url" 2>>"$LOG_FILE") || {
        log_error "Failed to fetch playlist metadata for: $url"
        return 1
    }
    
    echo "$metadata"
}

# Fetch individual track metadata
fetch_track_metadata() {
    local track_id="$1"
    local metadata
    
    log_debug "Fetching track metadata for: $track_id"
    
    metadata=$(yt-dlp --dump-json "https://www.youtube.com/watch?v=${track_id}" 2>>"$LOG_FILE") || {
        log_error "Failed to fetch track metadata for: $track_id"
        return 1
    }
    
    # Check if metadata is valid JSON
    if ! echo "$metadata" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response for track: $track_id"
        return 1
    fi
    
    echo "$metadata"
}

# Extract field from JSON with fallback
extract_json_field() {
    local json="$1"
    local field="$2"
    local default="$3"
    local value
    
    value=$(jq -r ".$field // \"$default\"" <<< "$json" 2>>"$LOG_FILE") || {
        log_error "Failed to parse JSON field: $field"
        echo "$default"
        return 1
    }
    
    echo "$value"
}

# DATABASE OPERATIONS
# ===================

# Check if track exists in database
track_exists() {
    local track_id="$1"
    local count
    
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tracks WHERE id = '$(sqlite_escape "$track_id")';")
    [[ "$count" -gt 0 ]]
}

# Insert or update track in database
insert_track() {
    local track_id="$1"
    local playlist_id="$2"
    local track_number="$3"
    local title="$4"
    local artist="$5"
    local album="$6"
    local thumbnail_url="$7"

    if ! sqlite3 "$DB_FILE" << EOF
INSERT OR REPLACE INTO tracks (id, playlist_id, track_number, title, artist, album, thumbnail_url)
VALUES (
    '$(sqlite_escape "$track_id")',
    '$(sqlite_escape "$playlist_id")',
    $track_number,
    '$(sqlite_escape "$title")',
    '$(sqlite_escape "$artist")',
    '$(sqlite_escape "$album")',
    '$(sqlite_escape "$thumbnail_url")'
);
EOF
    then
        log_error "Failed to insert track: $track_id"
        return 1
    fi
}

# Get track count for playlist
get_playlist_track_count() {
    local playlist_id="$1"
    sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")';"
}

# Process individual track and add to database
process_track() {
    local track_id="$1"
    local playlist_id="$2"
    local track_number="$3"
    local index_display="$4"
    local total_tracks="$5"
    
if track_exists "$track_id"; then
    local existing_title
    existing_title=$(sqlite3 "$DB_FILE" "SELECT title FROM tracks WHERE id = '$(sqlite_escape "$track_id")';")
    echo -e "${RED}[$index_display/$total_tracks] Exists:${RESET} $existing_title"
    return 0
fi
    
    local metadata title artist album
    metadata=$(fetch_track_metadata "$track_id") || return 1
    title=$(extract_json_field "$metadata" "title" "$DEFAULT_TRACK_TITLE")
    artist=$(extract_json_field "$metadata" "artist" "$DEFAULT_ARTIST")
    album=$(extract_json_field "$metadata" "album" "$DEFAULT_ALBUM")
thumbnail_url=$(extract_json_field "$metadata" "thumbnail" "")

echo -e "${GREEN}[$index_display/$total_tracks] ${RESET}$title"

insert_track "$track_id" "$playlist_id" "$track_number" "$title" "$artist" "$album" "$thumbnail_url" || {
    log_error "Failed to insert track: $track_id"
    return 1
}
    return 0
}

# Process entire playlist
process_playlist() {
    local input="$1"
    local url playlist_id playlist_metadata playlist_title
    local -a track_ids
    local total_tracks new_count
    
    # Extract playlist ID first (handles both full URLs and playlist IDs)
    playlist_id=$(extract_playlist_id "$input") || return 1
    
    # Construct full YouTube Music URL for yt-dlp
    url="https://music.youtube.com/playlist?list=$playlist_id"
    
    #log_info "Processing URL: $url"
    
    # Fetch playlist metadata
    playlist_metadata=$(fetch_playlist_metadata "$url") || return 1
    
    # Extract playlist title
    playlist_title=$(extract_json_field "$playlist_metadata" "title" "$DEFAULT_PLAYLIST_TITLE")
    #log_info "Validating playlist: \"$playlist_title\""
    log_info "$YELLOW"  "$playlist_title"
    
    # Extract track IDs
    mapfile -t track_ids < <(jq -r '.entries[].id' <<< "$playlist_metadata" 2>>"$LOG_FILE")
    total_tracks=${#track_ids[@]}
    
    if [[ $total_tracks -eq 0 ]]; then
        log_error "No tracks found in playlist: $playlist_title"
        return 1
    fi
    
    log_info "$YELLOW" "Processing $total_tracks tracks"
    echo ""
    
    # Process each track
    for i in "${!track_ids[@]}"; do
        local track_number=$((i + 1))
        local index_display
        local track_id="${track_ids[i]}"
        
        printf -v index_display "$TRACK_NUMBER_FORMAT" "$track_number"
        
        process_track "$track_id" "$playlist_id" "$track_number" "$index_display" "$total_tracks" || {
            log_error "Failed to process track $track_number: $track_id"
            continue
        }
    done
    # Display summary
    new_count=$(get_playlist_track_count "$playlist_id")
#    log_info "Finished processing playlist: \"$playlist_title\""
#    log_info "Database now contains $new_count tracks for album: $playlist_title"
    return 0
}


