#!/bin/bash

# Define modern hacker aesthetic colors
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color (Reset)

# Temporary file to store the original MAC
TEMP_MAC_FILE="/tmp/original_mac.txt"

clear
# ASCII Art: GHOST (Font: Tist style)
echo -e "${BRIGHT_GREEN}"
echo "      ::::::::   ::::::::  :::    :::  :::::::: ::::::::::: "
echo "    :+:    :+: :+:    :+: :+:    :+: :+:    :+:    :+:      "
echo "   +:+        +:+    +:+ +:+    +:+ +:+           +:+       "
echo "  :#:        +#+    +:+ +#++:++#++ +#++:++#+     +#+        "
echo " +#+   +#+# +#+    +#+ +#+    +#+        +#+    +#+         "
echo "#+#    #+# #+#    #+# #+#    #+# #+#    #+#    #+#          "
echo "########   ########  ###    ###  ########     ###           "
echo -e "   -- TERMINAL NETWORK CLOAKING TOOL v2.0 --${NC}\n"

# 1. Identify Wi-Fi Interface
INTERFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')

if [ -z "$INTERFACE" ]; then
    echo -e "${RED}[ERROR] No Wi-Fi interface detected.${NC}"
    exit 1
fi

# 2. Get the hardware (original) MAC address
ORIGINAL_HW_MAC=$(networksetup -getmacaddress $INTERFACE | awk '{print $3}')

echo -e "${CYAN}[INTERFACE] Using $INTERFACE${NC}"
echo -e "${CYAN}[HW_ADDR]   Factory MAC: $ORIGINAL_HW_MAC${NC}\n"

# Menu options
echo "1) 👻 Spoof MAC Address (Randomize)"
echo "2) 🔄 Restore Original MAC Address"
echo "3) 🧹 Flush DNS Cache (Fix connection issues)"
echo "4) ❌ Exit"
read -p "NETWORK > " choice

case $choice in
    1)
        # Create backup if it doesn't exist
        if [ ! -f "$TEMP_MAC_FILE" ]; then
            echo "$ORIGINAL_HW_MAC" > "$TEMP_MAC_FILE"
            echo -e "${GREEN}[BACKUP] Current MAC address backed up.${NC}"
        fi
        
        # Generate a random valid MAC
        NEW_MAC=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//' | sed 's/^././' | sed 's/./2/')
        
        echo -e "\n${CYAN}[1/2] Changing $INTERFACE to $NEW_MAC...${NC}"
        echo -e "${YELLOW}(Requires sudo password)${NC}"
        sudo ifconfig $INTERFACE ether $NEW_MAC
        
        echo -e "${GREEN}[2/2] MAC address changed successfully.${NC}"
        echo -e "${YELLOW}Notice: Toggle Wi-Fi OFF/ON if the connection drops.${NC}"
        ;;
    2)
        if [ -f "$TEMP_MAC_FILE" ]; then
            SAVED_MAC=$(cat "$TEMP_MAC_FILE")
            echo -e "\n${CYAN}[1/2] Restoring saved original MAC: $SAVED_MAC...${NC}"
            echo -e "${YELLOW}(Requires sudo password)${NC}"
            sudo ifconfig $INTERFACE ether $SAVED_MAC
            
            echo -e "${GREEN}[2/2] Original MAC address restored.${NC}"
            echo -e "${YELLOW}Notice: Toggle Wi-Fi OFF/ON to reconnect.${NC}"
            rm "$TEMP_MAC_FILE"
        else
            echo -e "\n${YELLOW}[INFO] Your original hardware MAC ($ORIGINAL_HW_MAC) is already active.${NC}"
        fi
        ;;
    3)
        echo -e "\n${CYAN}[1/2] Flushing DNS Cache...${NC}"
        echo -e "${YELLOW}(Requires sudo password)${NC}"
        sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
        echo -e "${GREEN}[2/2] DNS cache cleared.${NC}"
        ;;
    4)
        echo -e "\nExiting."
        exit 0
        ;;
    *)
        echo "Invalid selection."
        ;;
esac
