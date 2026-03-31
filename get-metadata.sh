#!/usr/bin/env bash

set -euo pipefail 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "$SCRIPT_DIR/lib/"*.sh; do
  [ -e "$file" ] && source "$file"
done

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    get_metadata_main "$@"
fi

