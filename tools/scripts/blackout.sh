#!/bin/bash

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}"
echo "  ██████╗ ██╗      █████╗  ██████╗██╗  ██╗ ██████╗ ██╗   ██╗████████╗"
echo "  ██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔═══██╗██║   ██║╚══██╔══╝"
echo "  ██████╔╝██║     ███████║██║     █████╔╝ ██║   ██║██║   ██║   ██║   "
echo "  ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██║   ██║██║   ██║   ██║   "
echo "  ██████╔╝███████╗██║  ██║╚██████╗██║  ██╗╚██████╔╝╚██████╔╝   ██║   "
echo "  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝    ╚═╝   "
echo -e "          -- PERIMETER SURVEILLANCE ACTIVE --${NC}\n"

# Get initial USB state
INITIAL_USB=$(system_profiler SPUSBDataType | grep "Product ID" | wc -l)

echo -e "${CYAN}[SYSTEM] Initializing Watchdog...${NC}"
echo -e "${CYAN}[SYSTEM] Current USB Devices: $INITIAL_USB${NC}"
echo -e "${YELLOW}[!] ARMING SYSTEM. SENSORS ACTIVE...${NC}"
echo "------------------------------------------------"

# Loop to watch for changes
while true; do
    CURRENT_USB=$(system_profiler SPUSBDataType | grep "Product ID" | wc -l)
    CURRENT_POWER=$(pmset -g batt | grep "AC Power" | wc -l)

    # Check for new USB devices
    if [ "$CURRENT_USB" -gt "$INITIAL_USB" ]; then
        echo -e "\n${RED}[!!!] ALERT: NEW USB DEVICE DETECTED! [$(date)]${NC}"
        # Optional: Lock screen immediately for safety
        # pmset displaysleepnow
    fi

    # Check if charger was unplugged
    if [ "$CURRENT_POWER" -eq 0 ]; then
         echo -ne "${RED}[!!!] ALERT: POWER DISCONNECTED! [$(date)]${NC}\r"
    fi

    # Minimal CPU usage
    sleep 2
done
