# Initialize directory structure and logging
initialize_environment() {
    mkdir -p "$BASE_DIR"
    : > "$LOG_FILE"  
    # Clear previous log file
}


