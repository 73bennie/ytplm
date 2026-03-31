list_inconsistent_playlists() {
  sqlite3 -readonly "$DB" "
    SELECT playlist_id,
           GROUP_CONCAT(DISTINCT artist),
           GROUP_CONCAT(DISTINCT album)
    FROM tracks
    GROUP BY playlist_id
    HAVING COUNT(DISTINCT artist || ' - ' || album) > 1;
  " | while IFS='|' read -r id artists albums; do
    first_artist=$(echo "$artists" | cut -d',' -f1)
    first_album=$(echo "$albums" | cut -d',' -f1)
#    echo "|$first_artist - $first_album"
    echo "$id|$first_artist - $first_album"
  done
}


