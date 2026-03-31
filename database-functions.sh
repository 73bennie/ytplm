#!/usr/bin/env bash

source "lib/config.sh"
source "lib/functions.sh"
source "lib/sqlite_escape.sh"

while true; do
    clear
    echo -e "${CYAN}=== Database Functions ===${RESET}"
    echo -e "${GREEN}1)${RESET} Backup Database"
    echo -e "${GREEN}2)${RESET} Restore Database"
    echo -e "${GREEN}3)${RESET} Backup plist.txt"
    echo -e "${GREEN}4)${RESET} Restore plist.txt"
    echo -e "${GREEN}5)${RESET} Edit plist.txt"
    echo -e "${GREEN}6)${RESET} Clean Database"
    echo -e "${GREEN}7)${RESET} Show Database Statistics"
    echo -e "${GREEN}8)${RESET} Batch Operations"
    echo -e "${GREEN}0)${RESET} Return to Main Menu"
    echo
    read -p "Choose an option: " option

    case "$option" in
        1)
            clear
            echo -e "${CYAN}=== Backup Database ===${RESET}"
            echo
            backup_database
            ;;
        2)
            clear
            echo -e "${CYAN}=== Restore Database ===${RESET}"
            echo
            restore_database
            ;;
        3)
            clear
            echo -e "${CYAN}=== Backup plist.txt ===${RESET}"
            echo
            backup_plist
            ;;
        4)
            clear
            echo -e "${CYAN}=== Restore plist.txt ===${RESET}"
            echo
            restore_plist
            ;;
        5)
            clear
            echo -e "${CYAN}=== Edit plist.txt ===${RESET}"
            echo
            edit_plist
            ;;
        6)
            clear
            echo -e "${CYAN}=== Clean Database ===${RESET}"
            echo
            clean_database
            ;;
        7)
            clear
            echo -e "${CYAN}=== Show Database Statistics ===${RESET}"
            echo
            show_database_stats
            ;;
        8)
            clear
            echo -e "${CYAN}=== Batch Operations ===${RESET}"
            echo
            echo "Batch operations coming soon..."
            echo "This will allow operations on multiple albums at once."
            ;;
        "")
            break
            ;;
        0)
            break
            ;;
        *)
            echo -e "${RED}Invalid option. Please choose between 0 and 8, or press Enter to return.${RESET}"
            sleep 1
            ;;
    esac
done 