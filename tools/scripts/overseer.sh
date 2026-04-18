#!/bin/bash

# Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${PURPLE}"
echo "  ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗███████╗██████╗ "
echo "  ██╔══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗"
echo "  ██║  ██║██║   ██║█████╗  ██████╔╝███████╗█████╗  █████╗  ██████╔╝"
echo "  ██║  ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝  ██╔══╝  ██╔══██╗"
echo "  ██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗███████╗██║  ██║"
echo "  ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝"
echo -e "             -- SYSTEM PROCESS INTERROGATOR v1.0 --${NC}\n"

# Table Header
printf "${CYAN}%-7s %-20s %-10s %-10s %-10s${NC}\n" "PID" "PROCESS NAME" "CPU%" "MEM%" "STATUS"
echo "----------------------------------------------------------------------"

# Get top 10 resource hogs
ps -axro pid,comm,pcpu,pmem,state | head -n 11 | tail -n 10 | while read pid comm cpu mem state; do
    # Shorten path to just app name
    app_name=$(basename "$comm")
    printf "%-7s %-20s %-10s %-10s %-10s\n" "$pid" "${app_name:0:19}" "$cpu%" "$mem%" "$state"
done

echo -e "\n${YELLOW}[?] ENTER PID TO TERMINATE OR 'q' TO ABORT:${NC}"
read -p "OVERSEER > " target_pid

if [[ "$target_pid" == "q" ]]; then
    echo "Exiting Overseer..."
    exit 0
fi

# Verification and "The Reap"
if ps -p $target_pid > /dev/null; then
    process_name=$(ps -p $target_pid -o comm= | basename $(cat))
    echo -e "${RED}[!] TARGET ACQUIRED: $process_name ($target_pid)${NC}"
    read -p "CONFIRM REAP? (y/n): " confirm
    
    if [[ "$confirm" == "y" ]]; then
        echo -ne "${RED}REAPING... [---       ]${NC}\r"
        sleep 0.3
        echo -ne "${RED}REAPING... [------    ]${NC}\r"
        sleep 0.3
        echo -ne "${RED}REAPING... [--------- ]${NC}\r"
        kill -9 $target_pid
        sleep 0.2
        echo -e "\n${PURPLE}[+] PROCESS $target_pid HAS BEEN HARVESTED.${NC}"
    else
        echo "Target spared."
    fi
else
    echo -e "${RED}[ERROR] PID $target_pid NOT FOUND IN SECTOR.${NC}"
fi
