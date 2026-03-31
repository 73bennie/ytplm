#!/usr/bin/env bash

# Show current directory
#echo "Current directory: $(pwd)"
#echo

# Use readline (tab completion enabled)
read -e -p "Enter directory to scan for .opus files: " dir

# Allow empty input to return to menu
if [[ -z "$dir" ]]; then
    exit 0
fi

# Expand ~ to $HOME
dir="${dir/#\~/$HOME}"

# Validate directory
if [[ ! -d "$dir" ]]; then
    echo "❌ Error: '$dir' is not a valid directory."
    exit 1
fi

# Process files and pipe output to less
{
    for f in "$dir"/*.opus; do
        [[ -e "$f" ]] || continue
        echo "══════════════════════════════════════════════════"
        echo "File: $f"
        echo "══════════════════════════════════════════════════"
        ffprobe -v error -show_format -show_streams "$f"
        echo
    done
} | less

