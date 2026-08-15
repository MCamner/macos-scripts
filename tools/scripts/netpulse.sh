#!/bin/bash

# Colors
#
# Gated on the same condition as the central guard in ui/terminal-ui/mq-ui.sh: a
# TTY and no NO_COLOR (https://no-color.org). These assignments used to be
# unconditional, so `mqlaunch netpulse > file` wrote the escapes into the file and
# neither NO_COLOR=1 nor --no-color removed one of them — the P1 output contract
# held only for commands that went through the shared library.
#
# Only the escapes are conditional. The banner, the headings and every
# measurement below print identically in both modes; the variables expand to
# nothing rather than to a colour.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    BLUE=''
    CYAN=''
    GREEN=''
    RED=''
    YELLOW=''
    NC=''
fi

# Screen-clear is a terminal action, not output. `clear` writes ^[[3J^[[H^[[2J
# to whatever stdout is whenever it can read a terminfo entry, so redirecting to
# a file used to capture three escapes before the first line of the report.
if [[ -t 1 ]]; then
    clear 2>/dev/null || true
fi
echo -e "${BLUE}"
echo "  :::::::::  :::    ::: :::        ::::::::  :::::::::: "
echo "  :+:    :+: :+:    :+: :+:       :+:    :+: :+:        "
echo "  +:+    +:+ +:+    +:+ +:+       +:+        +:+        "
echo "  +#++:++#+  +#+    +:+ +#+       +#++:++#+  +#++:++#   "
echo "  +#+        +#+    +#+ +#+              +#+ +#+        "
echo "  #+#        #+#    #+# #+#       #+#    #+# #+#        "
echo "  ###         ########  ########## ########  ########## "
echo -e "      -- NETWORK LATENCY & SIGNAL DIAGNOSTIC --${NC}\n"

# 1. Wi-Fi Signal Strength (RSSI)
INTERFACE=$(networksetup -listallhardwareports | awk '/Wi-Fi/{getline; print $2}')
echo -e "${CYAN}[WIFI ANALYTICS] Interface: $INTERFACE${NC}"

# Extract RSSI and Noise using wdutil (macOS specific)
WIFI_INFO=$(wdutil info)
RSSI=$(echo "$WIFI_INFO" | grep "RSSI" | awk '{print $3}')
NOISE=$(echo "$WIFI_INFO" | grep "Noise" | awk '{print $3}')
CHANNEL=$(echo "$WIFI_INFO" | grep "Channel" | head -n 1 | awk '{print $3}')

if [ -z "$RSSI" ]; then
    echo -e "${RED}[!] Could not retrieve Wi-Fi metrics. Is Wi-Fi on?${NC}"
else
    echo -e "Signal Strength (RSSI): ${GREEN}${RSSI} dBm${NC} (Higher is better, e.g. -30 is great, -80 is bad)"
    echo -e "Noise Level:          ${YELLOW}${NOISE} dBm${NC}"
    echo -e "Active Channel:       ${CYAN}${CHANNEL}${NC}"
fi

echo -e "\n${CYAN}[LATENCY TEST] Pinging core nodes...${NC}"

# Function to ping and format
test_ping() {
    local label=$1
    local host=$2
    printf "%-15s " "$label"
    result=$(ping -c 3 -q $host 2>/dev/null | tail -n 1 | cut -d '/' -f 5)
    if [ -z "$result" ]; then
        echo -e "${RED}TIMEOUT${NC}"
    else
        echo -e "${GREEN}${result} ms${NC}"
    fi
}

test_ping "Local Router:" "$(route -n get default | grep gateway | awk '{print $2}')"
test_ping "Google DNS:" "8.8.8.8"
test_ping "Cloudflare:" "1.1.1.1"

echo -e "\n${CYAN}[STABILITY] Checking for packet loss (5s)...${NC}"
LOSS=$(ping -c 5 -q 1.1.1.1 | grep "packet loss" | awk -F', ' '{print $3}')
echo -e "Result: ${YELLOW}${LOSS}${NC}"

echo -e "\n${BLUE}Pulse diagnostic complete.${NC}"
