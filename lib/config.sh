# Config
DB_PATH="./ytdata"
DB_FILE="metadata.db"
DB_FULL_PATH="${DB_PATH}/${DB_FILE}"
EXIT_DB_ERROR=3

DB="${DB_FULL_PATH}"
# Use Windows-compatible download directory
DOWNLOAD_DIR="$HOME/storage/shared/Music"

# Color codes
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

readonly SCRIPT_NAME="$(basename "$0")"
readonly BASE_DIR="./ytdata"
readonly LOG_FILE="$BASE_DIR/logfile"
readonly DB_FILE="$BASE_DIR/metadata.db"
readonly TRACK_NUMBER_FORMAT="%02d"
readonly DEFAULT_PLAYLIST_TITLE="Untitled Playlist"
readonly DEFAULT_TRACK_TITLE="Untitled Track"
readonly DEFAULT_ARTIST="Unknown Artist"
readonly DEFAULT_ALBUM="Unknown Album"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_FILE_NOT_FOUND=2
readonly EXIT_DEPENDENCY_MISSING=3
readonly EXIT_DB_ERROR=4

