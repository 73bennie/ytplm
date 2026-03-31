#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "$SCRIPT_DIR/lib/"*.sh; do
  [ -e "$file" ] && source "$file"
done

clear
echo -e "${CYAN}=== Normalize Playlist Artist/Album ===${RESET}\n"

mapfile -t entries < <(list_inconsistent_playlists)

if [ "${#entries[@]}" -eq 0 ]; then
    echo -e "${GREEN}All playlists appear to be normalized.${RESET}"
    exit 0
fi

echo "Playlists needing normalization:"

for i in "${!entries[@]}"; do
  id="${entries[$i]%%|*}"
  info="${entries[$i]#*|}"
  printf "%2d) %s • %s\n" "$((i + 1))" "$id" "$info"
done

while true; do
  echo -ne "\nChoose playlist to normalize (number, or 0 to return): "
  read -r pick

  if [[ "$pick" == "0" ]]; then
    #echo -e "\e[33mReturning to main menu.\e[0m"
    exit 0
  elif [[ "$pick" =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#entries[@]} )); then
    chosen_id="${entries[$((pick - 1))]%%|*}"
    normalize_playlist_id "$chosen_id"
    break
  else
    echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#entries[@]}, or 0 to return.${RESET}"
  fi
done

