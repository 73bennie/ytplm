# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    local color="$1"
    shift
    echo -e "${color}[INFO] $*${RESET}"
}

log_error() {
    echo -e "${RED}Error:${RESET} $1" >&2
}

# =============================================================================
# DATABASE FUNCTIONS
# =============================================================================

createEnv() {
    mkdir -p "$DB_PATH"

    if ! sqlite3 "$DB_FULL_PATH" <<'EOF'
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS tracks (
    id TEXT PRIMARY KEY,
    playlist_id TEXT NOT NULL,
    track_number INTEGER NOT NULL,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT NOT NULL,
    thumbnail_url TEXT,
    downloaded INTEGER DEFAULT 0,
    tagged INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_playlist_id ON tracks(playlist_id);
CREATE INDEX IF NOT EXISTS idx_track_number ON tracks(track_number);
CREATE INDEX IF NOT EXISTS idx_downloaded ON tracks(downloaded);
EOF
    then
        log_error "Failed to initialize database"
        exit $EXIT_DB_ERROR
    fi
}

# Get artist and album for a playlist
get_playlist_info() {
    local playlist_id="$1"
    sqlite3 -separator '|' "$DB" "SELECT artist, album FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")' LIMIT 1;"
}

# Get thumbnail URL for a playlist
get_playlist_thumbnail() {
    local playlist_id="$1"
    sqlite3 "$DB" "SELECT thumbnail_url FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")' LIMIT 1;"
}

# Get track count for a playlist
get_playlist_track_count() {
    local playlist_id="$1"
    sqlite3 "$DB" "SELECT COUNT(*) FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")';"
}

# Get first track ID for a playlist
get_playlist_first_track() {
    local playlist_id="$1"
    sqlite3 "$DB" "SELECT id FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")' LIMIT 1;"
}

# Sanitize database entries (remove forbidden characters)
sanitize_db_entry() {
    echo "$1" |
    sed 's/[\/:*?"<>|\\]/ /g' |      # Replace forbidden characters with space
    sed 's/  */ /g' |                # Collapse multiple spaces
    sed 's/^ *//; s/ *$//'           # Trim leading/trailing spaces
}

# =============================================================================
# BACKUP AND RESTORE FUNCTIONS
# =============================================================================

backup_database() {
    local backup_dir="backups"
    local timestamp=$(date +"%m-%d-%Y_%I-%M-%S%p")
    local backup_file="$backup_dir/metadata_backup_$timestamp.db"
    
    mkdir -p "$backup_dir"
    
    if cp "$DB_FULL_PATH" "$backup_file"; then
        echo -e "${GREEN}✓ Database backed up to: $backup_file${RESET}"
    else
        echo -e "${RED}✗ Failed to backup database${RESET}"
    fi
    
    echo
    read -rp "Press Enter to continue..."
}

restore_database() {
    local backup_dir="backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${RED}No backups directory found${RESET}"
        return 1
    fi
    
    local backups=($(ls -t "$backup_dir"/metadata_backup_*.db 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${RED}No backup files found${RESET}"
        return 1
    fi
    
    echo "Available backups:"
    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        local date=$(echo "$filename" | sed 's/metadata_backup_\(.*\)\.db/\1/')
        echo "$((i+1))) $date - $filename"
    done
    
    echo
    echo -e "${GREEN}R)${RESET} Restore backup"
    echo -e "${GREEN}D)${RESET} Delete backup by number"
    echo -e "${GREEN}A)${RESET} Delete all backups (except most recent)"
    echo -e "${GREEN}0)${RESET} Cancel"
    echo
    read -p "Choose an option: " choice
    
    case "$choice" in
        [Rr])
            echo -ne "\nChoose backup to restore (number, or press enter to cancel): "
            read -r restore_choice
            
            if [[ -z "$restore_choice" ]]; then
                echo "Restore cancelled."
                return 0
            fi
            
            if [[ "$restore_choice" =~ ^[0-9]+$ ]] && (( restore_choice >= 1 && restore_choice <= ${#backups[@]} )); then
                local selected_backup="${backups[$((restore_choice-1))]}"
                echo -ne "Are you sure you want to restore from $selected_backup? This will overwrite the current database. (y/N): "
                read -r confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if cp "$selected_backup" "$DB_FULL_PATH"; then
                        echo -e "${GREEN}✓ Database restored from: $selected_backup${RESET}"
                    else
                        echo -e "${RED}✗ Failed to restore database${RESET}"
                    fi
                else
                    echo "Restore cancelled."
                fi
            else
                echo -e "${RED}Invalid choice${RESET}"
            fi
            ;;
        [Dd])
            echo -ne "\nEnter backup number to delete: "
            read -r delete_choice
            
            if [[ "$delete_choice" =~ ^[0-9]+$ ]] && (( delete_choice >= 1 && delete_choice <= ${#backups[@]} )); then
                local selected_backup="${backups[$((delete_choice-1))]}"
                echo -ne "Are you sure you want to delete $selected_backup? (y/N): "
                read -r confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if rm "$selected_backup"; then
                        echo -e "${GREEN}✓ Backup deleted: $selected_backup${RESET}"
                    else
                        echo -e "${RED}✗ Failed to delete backup${RESET}"
                    fi
                else
                    echo "Delete cancelled."
                fi
            else
                echo -e "${RED}Invalid choice${RESET}"
            fi
            ;;
        [Aa])
            if [[ ${#backups[@]} -le 1 ]]; then
                echo -e "${YELLOW}Only one backup exists. Cannot delete all backups.${RESET}"
                return 0
            fi
            
            echo -ne "Are you sure you want to delete all backups except the most recent (${#backups[@]} backups total, will delete $(( ${#backups[@]} - 1 )))? (y/N): "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local deleted_count=0
                for ((i=1; i<${#backups[@]}; i++)); do
                    if rm "${backups[$i]}"; then
                        deleted_count=$((deleted_count + 1))
                    fi
                done
                echo -e "${GREEN}✓ Deleted $deleted_count backups${RESET}"
            else
                echo "Delete cancelled."
            fi
            ;;
        0)
            echo "Operation cancelled."
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose R, D, A, or 0.${RESET}"
            ;;
    esac
}

backup_plist() {
    local backup_dir="backups"
    local timestamp=$(date +"%m-%d-%Y_%I-%M-%S%p")
    local backup_file="$backup_dir/plist_backup_$timestamp.txt"
    
    mkdir -p "$backup_dir"
    
    if [[ -f "ytdata/plist.txt" ]]; then
        if cp "ytdata/plist.txt" "$backup_file"; then
            echo -e "${GREEN}✓ plist.txt backed up to: $backup_file${RESET}"
        else
            echo -e "${RED}✗ Failed to backup plist.txt${RESET}"
        fi
    else
        echo -e "${RED}plist.txt not found${RESET}"
    fi
    
    echo
    read -rp "Press Enter to continue..."
}

restore_plist() {
    local backup_dir="backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${RED}No backups directory found${RESET}"
        return 1
    fi
    
    local backups=($(ls -t "$backup_dir"/plist_backup_*.txt 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${RED}No plist.txt backup files found${RESET}"
        return 1
    fi
    
    echo "Available plist.txt backups:"
    for i in "${!backups[@]}"; do
        local filename=$(basename "${backups[$i]}")
        local date=$(echo "$filename" | sed 's/plist_backup_\(.*\)\.txt/\1/')
        echo "$((i+1))) $date - $filename"
    done
    
    echo
    echo -e "${GREEN}R)${RESET} Restore backup"
    echo -e "${GREEN}D)${RESET} Delete backup by number"
    echo -e "${GREEN}A)${RESET} Delete all backups (except most recent)"
    echo -e "${GREEN}0)${RESET} Cancel"
    echo
    read -p "Choose an option: " choice
    
    case "$choice" in
        [Rr])
            echo -ne "\nChoose backup to restore (number, or press enter to cancel): "
            read -r restore_choice
            
            if [[ -z "$restore_choice" ]]; then
                echo "Restore cancelled."
                return 0
            fi
            
            if [[ "$restore_choice" =~ ^[0-9]+$ ]] && (( restore_choice >= 1 && restore_choice <= ${#backups[@]} )); then
                local selected_backup="${backups[$((restore_choice-1))]}"
                echo -ne "Are you sure you want to restore from $selected_backup? This will overwrite the current plist.txt. (y/N): "
                read -r confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if cp "$selected_backup" "ytdata/plist.txt"; then
                        echo -e "${GREEN}✓ plist.txt restored from: $selected_backup${RESET}"
                    else
                        echo -e "${RED}✗ Failed to restore plist.txt${RESET}"
                    fi
                else
                    echo "Restore cancelled."
                fi
            else
                echo -e "${RED}Invalid choice${RESET}"
            fi
            ;;
        [Dd])
            echo -ne "\nEnter backup number to delete: "
            read -r delete_choice
            
            if [[ "$delete_choice" =~ ^[0-9]+$ ]] && (( delete_choice >= 1 && delete_choice <= ${#backups[@]} )); then
                local selected_backup="${backups[$((delete_choice-1))]}"
                echo -ne "Are you sure you want to delete $selected_backup? (y/N): "
                read -r confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    if rm "$selected_backup"; then
                        echo -e "${GREEN}✓ Backup deleted: $selected_backup${RESET}"
                    else
                        echo -e "${RED}✗ Failed to delete backup${RESET}"
                    fi
                else
                    echo "Delete cancelled."
                fi
            else
                echo -e "${RED}Invalid choice${RESET}"
            fi
            ;;
        [Aa])
            if [[ ${#backups[@]} -le 1 ]]; then
                echo -e "${YELLOW}Only one backup exists. Cannot delete all backups.${RESET}"
                return 0
            fi
            
            echo -ne "Are you sure you want to delete all backups except the most recent (${#backups[@]} backups total, will delete $(( ${#backups[@]} - 1 )))? (y/N): "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local deleted_count=0
                for ((i=1; i<${#backups[@]}; i++)); do
                    if rm "${backups[$i]}"; then
                        deleted_count=$((deleted_count + 1))
                    fi
                done
                echo -e "${GREEN}✓ Deleted $deleted_count backups${RESET}"
            else
                echo "Delete cancelled."
            fi
            ;;
        0)
            echo "Operation cancelled."
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose R, D, A, or 0.${RESET}"
            ;;
    esac
}

# =============================================================================
# DATABASE MAINTENANCE FUNCTIONS
# =============================================================================

clean_database() {
    echo -e "${YELLOW}This will clean the database by removing:${RESET}"
    echo "- Tracks with empty or NULL artist/album names"
    echo "- Duplicate entries"
    echo "- Orphaned playlist entries"
    echo
    echo -e "${GREEN}1)${RESET} Test run (show what would be removed)"
    echo -e "${GREEN}2)${RESET} Clean database"
    echo -e "${GREEN}0)${RESET} Cancel"
    echo
    read -p "Choose an option: " choice

    case "$choice" in
        1)
            echo -e "${CYAN}=== Test Run - What would be removed ===${RESET}"
            echo
            
            # Count tracks with empty artist/album names
            local empty_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tracks WHERE artist IS NULL OR artist = '' OR album IS NULL OR album = '';" 2>/dev/null || echo "0")
            echo -e "${YELLOW}Tracks with empty artist/album names:${RESET} $empty_count"
            if [[ $empty_count -gt 0 ]]; then
                echo "Examples:"
                sqlite3 "$DB" "SELECT title, artist, album FROM tracks WHERE artist IS NULL OR artist = '' OR album IS NULL OR album = '' LIMIT 3;" 2>/dev/null | while IFS='|' read -r title artist album; do
                    echo "  - $title | $artist | $album"
                done
            fi
            echo
            
            # Count duplicate tracks
            local duplicate_count=$(sqlite3 "$DB" "SELECT COUNT(*) - COUNT(DISTINCT id) FROM tracks;" 2>/dev/null || echo "0")
            echo -e "${YELLOW}Duplicate tracks:${RESET} $duplicate_count"
            if [[ $duplicate_count -gt 0 ]]; then
                echo "Examples:"
                sqlite3 "$DB" "SELECT id, title, COUNT(*) as count FROM tracks GROUP BY id HAVING COUNT(*) > 1 LIMIT 3;" 2>/dev/null | while IFS='|' read -r id title count; do
                    echo "  - $title (ID: $id) - $count copies"
                done
            fi
            echo
            
            echo -e "${GREEN}Test run completed. No changes were made.${RESET}"
            echo
            read -rp "Press Enter to continue..."
            clear
            clean_database
            ;;
        2)
            echo -ne "Are you sure you want to clean the database? (y/N): "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "Cleaning database..."
                
                # Remove tracks with empty artist/album names
                local removed=$(sqlite3 "$DB" "DELETE FROM tracks WHERE artist IS NULL OR artist = '' OR album IS NULL OR album = ''; SELECT changes();")
                echo "Removed $removed tracks with empty artist/album names"
                
                # Remove duplicate tracks (same id)
                removed=$(sqlite3 "$DB" "DELETE FROM tracks WHERE rowid NOT IN (SELECT MIN(rowid) FROM tracks GROUP BY id); SELECT changes();")
                echo "Removed $removed duplicate tracks"
                
                echo -e "${GREEN}✓ Database cleaning completed${RESET}"
            else
                echo "Database cleaning cancelled."
            fi
            
            echo
            read -rp "Press Enter to continue..."
            ;;
        0)
            echo "Database cleaning cancelled."
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or 0.${RESET}"
            ;;
    esac
}

show_database_stats() {
    echo -e "${CYAN}Database Statistics:${RESET}"
    echo

    # Total tracks
    local total_tracks
    total_tracks=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tracks;" 2>/dev/null || echo "0")
    echo -e "${GREEN}Total tracks:${RESET} $total_tracks"

    # Total artists
    local total_artists
    total_artists=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT artist) FROM tracks WHERE artist IS NOT NULL AND artist != '';" 2>/dev/null || echo "0")
    echo -e "${GREEN}Total artists:${RESET} $total_artists"

    # Total albums
    local total_albums
    total_albums=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT album) FROM tracks WHERE album IS NOT NULL AND album != '';" 2>/dev/null || echo "0")
    echo -e "${GREEN}Total albums:${RESET} $total_albums"

    echo
    read -rp "Press Enter to continue..."
}

# =============================================================================
# FILE MANAGEMENT FUNCTIONS
# =============================================================================

tag_opus_file() {
    local infile="$1"
    local title="$2"
    local artist="$3"
    local album="$4"
    local track_id="$5"
    local tmpfile
    tmpfile="$(mktemp --suffix=".opus")"

    # Extract track number from filename (assumes format "## - Title.opus")
    local basename_only="$(basename "$infile" .opus)"
    local track_number="${basename_only%% -*}"

    # Tag using ffmpeg
    ffmpeg -loglevel error -y -i "$infile" -c copy \
        -metadata artist="$artist" \
        -metadata album="$album" \
        -metadata title="$title" \
        -metadata track="$track_number" \
        -metadata track_id="$track_id" \
        -metadata playlist_id="$playlist_id" \
        "$tmpfile"

    if [[ -s "$tmpfile" ]]; then
        mv "$tmpfile" "$infile"
        echo "  ✔ Tagged"
        echo ""
        sqlite3 "$DB" "UPDATE tracks SET tagged = 1 WHERE id = '$(sqlite_escape "$track_id")';"
        return 0
    else
        echo "  ⚠ Failed to tag: $infile"
        rm -f "$tmpfile"
        return 1
    fi
}

edit_plist() {
    local plist_file="ytdata/plist.txt"
    
    if [[ ! -f "$plist_file" ]]; then
        echo -e "${RED}plist.txt not found${RESET}"
        echo "Creating empty plist.txt file..."
        mkdir -p "ytdata"
        touch "$plist_file"
    fi
    
    # Try vim first, then $EDITOR, then fallback to other editors
    local editor_cmd
    if command -v vim >/dev/null 2>&1; then
        # Use vim with user configuration
        editor_cmd=(vim)
    elif [[ -n "$EDITOR" ]] && command -v "$EDITOR" >/dev/null 2>&1; then
        editor_cmd=("$EDITOR")
    elif command -v nano >/dev/null 2>&1; then
        editor_cmd=(nano)
    elif command -v notepad >/dev/null 2>&1; then
        editor_cmd=(notepad)
    else
        echo -e "${RED}No suitable editor found. Please set \$EDITOR environment variable.${RESET}"
        return 1
    fi
    
    if "${editor_cmd[@]}" "$plist_file"; then
        echo -e "${GREEN}✓ plist.txt edited successfully${RESET}"
        
        # Show the current contents
        echo
        echo -e "${CYAN}Current plist.txt contents:${RESET}"
        if [[ -s "$plist_file" ]]; then
            cat "$plist_file"
        else
            echo "(empty file)"
        fi
    else
        echo -e "${RED}✗ Error editing plist.txt${RESET}"
    fi
}

# Sanitize filename/directory name for Windows compatibility
sanitize_filename() {
    local input="$1"
    echo "$input" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[^[:print:]]//g' | sed 's/__*/_/g' | sed 's/^_*//;s/_*$//'
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Generic menu selection function
menu_selection() {
    local prompt="$1"
    local max_options="$2"
    local allow_zero="${3:-false}"
    
    while true; do
        echo -ne "$prompt"
        read -r choice
        
        if [[ -z "$choice" ]]; then
            return 1  # No selection made
        elif [[ "$choice" == "0" ]] && [[ "$allow_zero" == "true" ]]; then
            return 0  # Zero selected
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max_options )); then
            echo "$choice"
            return 0
        else
            echo -e "${RED}Invalid choice. Please enter a number between 1 and $max_options${RESET}"
            sleep 1
        fi
    done
}

# Convert Unix path to Windows path
unix_to_win_path() {
    # Converts /c/Users/... to C:\Users\...
    echo "$1" | sed -E 's|^/([a-zA-Z])/|\1:\\|' | sed 's|/|\\|g'
}

# Main function for get-metadata.sh
get_metadata_main() {
    local url url_file
    url_file="ytdata/plist.txt"
    # Initialize environment
    echo ""
    initialize_environment
    
    # Process based on input type
    if [[ -n "$url_file" ]]; then
        process_url_file "$url_file"
    elif [[ -n "$url" ]]; then
        process_url "$url"
    fi
    return $EXIT_SUCCESS
}


