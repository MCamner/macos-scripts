#!/bin/bash

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "  ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗"
echo "  ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝"
echo "  ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ "
echo "  ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ "
echo "  ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗"
echo "  ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝"
echo -e "      -- ULTIMATE MAC LINUX INSTALLER --${NC}\n"

# Architecture Check
ARCH=$(uname -m)
if [ "$ARCH" == "arm64" ]; then
    echo -e "${GREEN}[INFO] System: Apple Silicon (M-series) detected.${NC}"
    echo -e "${YELLOW}Notice: M1/M2/M3 Macs require Asahi Linux for native support.${NC}\n"
    echo "1) Install Asahi Linux (Run official installer directly)"
    echo "2) Create USB for Intel Mac (To be used on a different machine)"
    echo "3) Exit"
    read -p "Selection [1-3]: " m_choice

    case $m_choice in
        1)
            echo -e "\n${CYAN}[SYSTEM] Launching official Asahi Linux installer...${NC}"
            echo "Please follow the on-screen instructions carefully."
            sleep 2
            curl -L https://alx.sh | sh
            exit
            ;;
        2)
            echo -e "\n${CYAN}[PROCEEDING] Preparing USB creation for Intel Mac...${NC}"
            ;;
        3)
            echo -e "\n${YELLOW}Exiting. No changes made.${NC}"
            exit 0
            ;;
        *)
            echo "Invalid selection. Exiting."
            exit 1
            ;;
    esac
else
    echo -e "${GREEN}[INFO] System: Intel Processor detected.${NC}\n"
    echo "1) Continue to USB Creation"
    echo "2) Exit"
    read -p "Selection [1-2]: " i_choice
    if [ "$i_choice" == "2" ]; then
        echo -e "\n${YELLOW}Exiting. No changes made.${NC}"
        exit 0
    fi
fi

# Selection Menu for ISO
echo -e "\n${YELLOW}Select Linux Distribution for USB:${NC}"
echo "1) Ubuntu Desktop 24.04 LTS (Recommended)"
echo "2) Linux Mint (Lightweight/User-friendly)"
echo "3) Kali Linux (Security/Pentesting)"
echo "4) Exit"
read -p "Selection [1-4]: " os_choice

case $os_choice in
    1) URL="https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"; FILE="ubuntu.iso" ;;
    2) URL="https://mirrors.layeronline.com/linuxmint/stable/21.3/linuxmint-21.3-cinnamon-64bit.iso"; FILE="mint.iso" ;;
    3) URL="https://cdimage.kali.org/kali-2024.1/kali-linux-2024.1-installer-amd64.iso"; FILE="kali.iso" ;;
    4) echo -e "\n${YELLOW}Exiting.${NC}"; exit 0 ;;
    *) echo "Invalid selection. Exiting."; exit 1 ;;
esac

# Download Step
echo -e "\n${CYAN}[1/3] Downloading $FILE... (This may take a while)${NC}"
curl -L -o "$FILE" "$URL"

# Drive Identification
echo -e "\n${YELLOW}[2/3] Please insert your USB drive.${NC}"
echo "Searching for external drives..."
sleep 1
diskutil list external | grep /dev/disk
echo -ne "\nEnter the Disk ID (e.g., disk4) or type 'exit': "
read DISK_ID

if [[ "$DISK_ID" == "exit" || -z "$DISK_ID" ]]; then
    echo "Exiting. Cleaning up..."
    rm -f "$FILE"
    exit 0
fi

# Flash Step
echo -e "\n${RED}[3/3] CRITICAL WARNING: All data on $DISK_ID will be DESTROYED!${NC}"
read -p "Are you absolutely sure you want to proceed? (y/n): " confirm

if [ "$confirm" == "y" ]; then
    echo -e "${YELLOW}Starting write process. Please enter your Mac password if prompted.${NC}"
    diskutil unmountDisk /dev/$DISK_ID
    
    # Using 'r' before DISK_ID for raw speed on macOS
    sudo dd if="$FILE" of=/dev/r$DISK_ID bs=1m status=progress
    
    diskutil eject /dev/$DISK_ID
    echo -e "\n${GREEN}SUCCESS! You can now restart your Mac and hold Option (Alt) to boot.${NC}"
    rm "$FILE"
else
    echo -e "${YELLOW}Operation cancelled. Cleaning up...${NC}"
    rm -f "$FILE"
fi
