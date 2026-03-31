log_error() {
    echo "[ERROR] $*" >&2
    echo "[ERROR] $*" >> "$LOG_FILE"
}

log_debug() {
    echo "[DEBUG] $*" >> "$LOG_FILE"
}


