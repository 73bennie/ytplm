# Parse command line arguments
parse_arguments() {
    local url="" url_file=""
    
    while getopts ":f:h" opt; do
        case $opt in
            f) url_file="$OPTARG" ;;
            h) usage ;;
            \?) log_error "Invalid option: -$OPTARG"; usage ;;
            :) log_error "Option -$OPTARG requires an argument"; usage ;;
        esac
    done
    shift $((OPTIND - 1))
    
    # Use remaining argument as URL if not using -f
    [[ -n "${1:-}" ]] && url="$1"
    
    # Validate input
    if [[ -z "$url" && -z "$url_file" ]]; then
        log_error "No playlist URL or file provided"
        usage
    fi
    
    if [[ -n "$url" && -n "$url_file" ]]; then
        log_error "Cannot specify both URL and file. Choose one."
        usage
    fi
}


