# Escape strings for SQLite (more robust than original)
sqlite_escape() {
    local input="$1"
    # Escape single quotes and handle null bytes
    printf '%s\n' "$input" | sed "s/'/''/g" | tr -d '\0'
}


