normalize_playlist_id() {
  local pid="$1"
  echo -e "\nUnique artist/album combinations for playlist $pid:\n" >&2

  mapfile -t combos < <(sqlite3 -readonly "$DB" "
    SELECT DISTINCT artist || '|' || album
    FROM tracks
    WHERE playlist_id = '$(sqlite_escape "$pid")';
  ")

  for i in "${!combos[@]}"; do
    artist="$(cut -d'|' -f1 <<< "${combos[$i]}")"
    album="$(cut -d'|' -f2 <<< "${combos[$i]}")"
    printf "%2d) %s — %s\n" "$((i + 1))" "$artist" "$album"
  done

  echo " C) Enter custom artist and album"
  echo " 0) Cancel"

  local sel_artist sel_album

  while true; do
    echo -ne "\nChoose correct combination (number, C for custom, or 0 to cancel): "
    read -r selection

    if [[ "$selection" == "0" ]]; then
      echo -e "\e[33mCancelled. Returning to playlist selection.\e[0m"
      return 0

    elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#combos[@]} )); then
      combo="${combos[$((selection - 1))]}"
      sel_artist="$(cut -d'|' -f1 <<< "$combo")"
      sel_album="$(cut -d'|' -f2 <<< "$combo")"
      break

    elif [[ "$selection" =~ ^[Cc]$ ]]; then
      while true; do
        echo -ne "Enter custom artist: "
        read -r sel_artist
        echo -ne "Enter custom album: "
        read -r sel_album

        if [[ -z "$sel_artist" || -z "$sel_album" ]]; then
          echo -e "\e[31mBoth artist and album must be non-empty.\e[0m"
          continue
        fi

        echo -e "\nYou entered:"
        echo -e "  Artist: \e[36m$sel_artist\e[0m"
        echo -e "  Album:  \e[36m$sel_album\e[0m"
        echo -ne "\nIs this correct? (y/n): "
        read -r confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          break 2  # break out of both loops
        else
          echo -e "\e[33mLet's try again...\e[0m"
        fi
      done

    else
      echo -e "\e[31mInvalid selection. Please enter a valid number, C for custom, or 0 to cancel.\e[0m"
    fi
  done

  # Use sqlite_escape function for proper escaping
  escaped_artist=$(sqlite_escape "$sel_artist")
  escaped_album=$(sqlite_escape "$sel_album")

  echo -e "\nUpdating tracks in playlist $pid to artist='\e[33m$sel_artist\e[0m', album='\e[33m$sel_album\e[0m'..."
  sqlite3 "$DB" "
    UPDATE tracks
    SET artist = '$escaped_artist', album = '$escaped_album'
    WHERE playlist_id = '$(sqlite_escape "$pid")';
  "
  echo "Done."
}

#normalize_playlist_id() {
#  local pid="$1"
#  echo -e "\nUnique artist/album combinations for playlist $pid:\n" >&2
#
#  mapfile -t combos < <(sqlite3 -readonly "$DB" "
#    SELECT DISTINCT artist || '|' || album
#    FROM tracks
#    WHERE playlist_id = '$pid';
#  ")
#
#  for i in "${!combos[@]}"; do
#    artist="$(cut -d'|' -f1 <<< "${combos[$i]}")"
#    album="$(cut -d'|' -f2 <<< "${combos[$i]}")"
#    printf "%2d) %s — %s\n" "$((i + 1))" "$artist" "$album"
#  done
#
#  echo " C) Enter custom artist and album"
#  echo " 0) Cancel"
#
#  while true; do
#    echo -ne "\nChoose correct combination (number, C for custom, or 0 to cancel): "
#    read -r selection
#
#    if [[ "$selection" == "0" ]]; then
#      echo -e "\e[33mCancelled. Returning to playlist selection.\e[0m"
#      return 0
#
#    elif [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#combos[@]} )); then
#      combo="${combos[$((selection - 1))]}"
#      sel_artist="$(cut -d'|' -f1 <<< "$combo")"
#      sel_album="$(cut -d'|' -f2 <<< "$combo")"
#      break
#
##    elif [[ "$selection" =~ ^[Cc]$ ]]; then
##      echo -ne "Enter custom artist: "
##      read -r sel_artist
##      echo -ne "Enter custom album: "
##      read -r sel_album
##
##      if [[ -z "$sel_artist" || -z "$sel_album" ]]; then
##        echo -e "\e[31mBoth artist and album must be non-empty.\e[0m"
##        continue
##      fi
##      break
#elif [[ "$selection" =~ ^[Cc]$ ]]; then
#  while true; do
#    echo -ne "Enter custom artist: "
#    read -r sel_artist
#    echo -ne "Enter custom album: "
#    read -r sel_album
#
#    if [[ -z "$sel_artist" || -z "$sel_album" ]]; then
#      echo -e "\e[31mBoth artist and album must be non-empty.\e[0m"
#      continue
#    fi
#
#    echo -e "\nYou entered:"
#    echo -e "  Artist: \e[36m$sel_artist\e[0m"
#    echo -e "  Album:  \e[36m$sel_album\e[0m"
#    echo -ne "\nIs this correct? (y/n): "
#    read -r confirm
#
#    if [[ "$confirm" =~ ^[Yy]$ ]]; then
#      break
#    else
#      echo -e "\e[33mLet's try again...\e[0m"
#    fi
#  done
#
#    else
#      echo -e "\e[31mInvalid selection. Please enter a valid number, C for custom, or 0 to cancel.\e[0m"
#    fi
#  done
#
#  echo -e "\nUpdating tracks in playlist $pid to artist='\e[33m$sel_artist\e[0m', album='\e[33m$sel_album\e[0m'..."
#  sqlite3 "$DB" "
#    UPDATE tracks
#    SET artist = '$sel_artist', album = '$sel_album'
#    WHERE playlist_id = '$pid';
#  "
#  echo "Done."
#}


