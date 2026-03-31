#!/usr/bin/env bash

source "lib/config.sh"  # Sets DB and DOWNLOAD_DIR
source "lib/functions.sh"
source ./lib/sqlite_escape.sh

echo "🎵 Enter album name to reset (or press enter to view all albums):"
read -r input

if [[ -z "$input" ]] || [[ "$input" == "list" ]]; then
    echo -e "\n📀 All albums in database:\n"
    albums=$(sqlite3 -separator '|' "$DB" "
      SELECT DISTINCT artist, album, playlist_id
      FROM tracks
      WHERE artist IS NOT NULL AND TRIM(artist) != ''
        AND album IS NOT NULL AND TRIM(album) != ''
        AND LENGTH(artist) > 1
        AND LENGTH(album) > 1
      ORDER BY artist, album;
    ")

    if [[ -z "$albums" ]]; then
        echo "❌ No albums found in database."
        sleep 1
        exit 1
    fi

    i=1
    declare -A IDX_TO_INFO
    while IFS='|' read -r artist album pid; do
        # Skip entries that look corrupted (contain multiple album names)
        if [[ "$album" =~ .*[A-Z][a-z].*[A-Z][a-z].* ]] && [[ "$album" =~ .*[0-9].* ]]; then
            continue
        fi
        echo "$i) $artist - $album"
        IDX_TO_INFO[$i]="$artist|$album|$pid"
        ((i++))
    done <<< "$albums"

    echo -ne "\nChoose an album by number (or press enter to exit): "
    read -r choice
    
    if [[ -z "$choice" ]]; then
        sleep 1
        exit 0
    fi
    
    info="${IDX_TO_INFO[$choice]}"

    if [[ -z "$info" ]]; then
        echo "❌ Invalid choice."
        sleep 1
        exit 1
    fi

else
    # Search by partial artist or album name
    matches=$(sqlite3 -separator '|' "$DB" "
      SELECT DISTINCT artist, album, playlist_id
      FROM tracks
      WHERE (artist LIKE '%' || '$input' || '%' OR album LIKE '%' || '$input' || '%')
        AND artist IS NOT NULL AND TRIM(artist) != ''
        AND album IS NOT NULL AND TRIM(album) != ''
        AND LENGTH(artist) > 1
        AND LENGTH(album) > 1
      ORDER BY artist, album;
    ")

    if [[ -z "$matches" ]]; then
        echo "❌ No matching albums found."
        sleep 1
        exit 1
    fi

    echo -e "\n📀 Matching albums:"
    i=1
    declare -A IDX_TO_INFO
    while IFS='|' read -r artist album pid; do
        # Skip entries that look corrupted (contain multiple album names)
        if [[ "$album" =~ .*[A-Z][a-z].*[A-Z][a-z].* ]] && [[ "$album" =~ .*[0-9].* ]]; then
            continue
        fi
        echo "$i) $artist - $album"
        IDX_TO_INFO[$i]="$artist|$album|$pid"
        ((i++))
    done <<< "$matches"

    echo -ne "\nChoose an album to reset (number, 0 to search again, or press enter to exit): "
    read -r choice
    
    if [[ -z "$choice" ]]; then
        exit 0
    elif [[ "$choice" == "0" ]]; then
        # Clear screen and restart the script
        clear
        exec "$0"
    fi
    
    info="${IDX_TO_INFO[$choice]}"

    if [[ -z "$info" ]]; then
        echo "❌ Invalid choice."
        exit 1
    fi
fi

IFS='|' read -r artist album playlist_id <<< "$info"

# Validate that we have the required data
if [[ -z "$artist" ]] || [[ -z "$album" ]] || [[ -z "$playlist_id" ]]; then
    echo "❌ Error: Missing artist, album, or playlist_id data"
    echo "  artist: '$artist'"
    echo "  album: '$album'"
    echo "  playlist_id: '$playlist_id'"
    exit 1
fi

# Sanitize album and artist names for folder operations
safe_album=$(sanitize_filename "$album")
safe_artist=$(sanitize_filename "$artist")

album_folder="$DOWNLOAD_DIR/$safe_artist/$safe_album"
unsanitized_album_folder="$DOWNLOAD_DIR/$artist/$album"
safe_artist_folder="$DOWNLOAD_DIR/$safe_artist"
unsanitized_artist_folder="$DOWNLOAD_DIR/$artist"

echo -e "\n⚠️  This will:"
echo " - Mark all tracks in '$album' as not downloaded"
echo " - Delete all opus files on the drive"
echo -n "Are you sure? [y/N]: "
read -r confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# Reset flags in DB
sqlite3 "$DB" "
  UPDATE tracks
  SET downloaded = 0, tagged = 0
  WHERE playlist_id = '$(sqlite_escape "$playlist_id")';
"

# Delete all opus files in the album folder (sanitized or unsanitized)
if [[ -d "$album_folder" ]]; then
    echo "⚠️  Deleting all opus files in: $album_folder"
    find "$album_folder" -type f -name '*.opus' -exec rm -f {} +
    echo "⚠️  Deleting cover art in: $album_folder"
    find "$album_folder" -type f -name 'folder.jpg' -exec rm -f {} +
    echo "⚠️  Deleting album folder: $album_folder"
    rmdir "$album_folder" 2>/dev/null || echo "  ⚠️  Could not remove album folder (may not be empty)"
    
    # Check if artist folder is now empty and remove it
    if [[ -d "$safe_artist_folder" ]] && [[ -z "$(find "$safe_artist_folder" -mindepth 1 -print -quit)" ]]; then
        echo "🧹 Deleting empty artist folder: $safe_artist_folder"
        rmdir "$safe_artist_folder" 2>/dev/null || echo "  ⚠️  Could not remove artist folder"
    fi
elif [[ -d "$unsanitized_album_folder" ]]; then
    echo "⚠️  Deleting all opus files in (unsanitized): $unsanitized_album_folder"
    find "$unsanitized_album_folder" -type f -name '*.opus' -exec rm -f {} +
    echo "⚠️  Deleting cover art in (unsanitized): $unsanitized_album_folder"
    find "$unsanitized_album_folder" -type f -name 'folder.jpg' -exec rm -f {} +
    echo "⚠️  Deleting album folder (unsanitized): $unsanitized_album_folder"
    rmdir "$unsanitized_album_folder" 2>/dev/null || echo "  ⚠️  Could not remove album folder (may not be empty)"
    
    # Check if artist folder is now empty and remove it
    if [[ -d "$unsanitized_artist_folder" ]] && [[ -z "$(find "$unsanitized_artist_folder" -mindepth 1 -print -quit)" ]]; then
        echo "🧹 Deleting empty artist folder: $unsanitized_artist_folder"
        rmdir "$unsanitized_artist_folder" 2>/dev/null || echo "  ⚠️  Could not remove artist folder"
    fi
else
    echo "⚠️  Album folder not found: $album_folder or $unsanitized_album_folder"
fi

# Prompt to remove playlist from DB
echo -ne "\n❓ Also delete this playlist from the database? (y/N): "
read -r delete_db
if [[ "$delete_db" =~ ^[Yy]$ ]]; then
    # Delete tracks for this playlist
    sqlite3 "$DB" "DELETE FROM tracks WHERE playlist_id = '$(sqlite_escape "$playlist_id")';"
    echo "🗑️  Deleted playlist ID $playlist_id from database."
else
    echo "✅ Playlist left in database (marked as not downloaded)."
fi

echo -e "\n✅ Done."
