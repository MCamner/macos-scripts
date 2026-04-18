#!/bin/bash

# Matrix colors
GREEN='\033[0;32m'
BRIGHT_GREEN='\033[1;32m'
NC='\033[0m'

# Function for the "decoding" effect
decode_text() {
    local text="$1"
    local delay=0.02
    for ((i=0; i<${#text}; i++)); do
        # Print random characters before showing the real one
        for ((j=0; j<5; j++)); do
            printf "\r${GREEN}%s${NC}%s" "${text:0:i}" "$(printf "\\x$(printf %x $((33 + RANDOM % 94)))")"
            sleep 0.01
        done
        printf "\r${BRIGHT_GREEN}%s${NC}" "${text:0:i+1}"
    done
    printf "\n"
}

clear
echo -e "${GREEN}"
echo "  ██████╗ ███████╗ ██████╗██████╗ ██╗   ██╗██████╗ ████████╗"
echo "  ██╔══██╗██╔════╝██╔════╝██╔══██╗╚██╗ ██╔╝██╔══██╗╚══██╔══╝"
echo "  ██║  ██║█████╗  ██║     ██████╔╝ ╚████╔╝ ██████╔╝   ██║   "
echo "  ██║  ██║██╔══╝  ██║     ██╔══██╗  ╚██╔╝  ██╔═══╝    ██║   "
echo "  ██████╔╝███████╗╚██████╗██║  ██║   ██║   ██║        ██║   "
echo "  ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝        ╚═╝   "
echo -e "      -- SYSTEM DECRYPTOR & VULNERABILITY SCAN --${NC}\n"

sleep 1

decode_text "[STATUS] INITIALIZING CORE OVERRIDE..."
sleep 0.5
decode_text "[SCAN] CHECKING OPEN NETWORK PORTS..."
# Real scan: List open ports (simplified)
netstat -anp tcp | grep LISTEN | head -n 5
sleep 0.5

decode_text "[SCAN] PROBING SYSTEM FIREWALL..."
# Real scan: Check firewall status
FW_STATUS=$(fdesetup status)
decode_text ">> $FW_STATUS"
sleep 0.5

decode_text "[SCAN] IDENTIFYING ACTIVE HIDDEN DAEMONS..."
# Real scan: Top 3 background processes
ps -axro pcpu,comm | head -n 4
sleep 1

echo -e "\n${BRIGHT_GREEN}[COMPLETE] SYSTEM SCAN SECURED.${NC}"
