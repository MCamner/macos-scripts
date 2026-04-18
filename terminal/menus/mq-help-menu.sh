#!/usr/bin/env bash

# Colors (Använder dina befintliga färgkoder för enhetlighet)
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

# Rensa skärmen för maximal effekt
clear

# --- NY ASCII LOGGA ---
echo -e "${PURPLE}"
echo "  __  __  ____  _             _    _   _   _____ _    _ "
echo " |  \/  |/ __ \| |           / \  | | | | / ____| |  | |"
echo " | \  / | |  | | |          / _ \ | | | || |    | |__| |"
echo " | |\/| | |  | | |         / ___ \| | | || |    |  __  |"
echo " | |  | | |__| | |____    / /   \ \ |_| || |____| |  | |"
echo " |_|  |_|\___\_\______|  /_/     \_\___/  \_____|_|  |_|"
echo -e "          -- S Y S T E M   H U B   v1.0 --${NC}\n"

echo -e "${CYAN}COMMAND INDEX${NC}"
echo -e "${BLUE}----------------------------------------------------------------------------------------${NC}"

echo -e "\n${PURPLE}CORE${NC}"
printf " mqlaunch              Open main menu\n"
printf " mqlaunch demo         Run guided demo mode\n"
printf " mqlaunch help         Show command index\n"
printf " mqlaunch palette      Open fuzzy command palette\n"
printf " mqlaunch system       Open System menu\n"

echo -e "\n${PURPLE}SECURITY & OPS (NEW)${NC}"
printf " mqlaunch mc           Open advanced system dashboard\n"
printf " mqlaunch ghost        Execute network cloaking (MAC/DNS)\n"
printf " mqlaunch pulse        Run network latency & signal diagnostic\n"
printf " mqlaunch scan         Run system vulnerability & port scan\n"
printf " mqlaunch reap         Open process interrogation (Overseer)\n"
printf " mqlaunch guard        Enable physical perimeter surveillance\n"

echo -e "\n${PURPLE}WORKFLOWS${NC}"
printf " mqlaunch perf         Open Performance menu\n"
printf " mqlaunch system check Run system check\n"
printf " mqlaunch dev          Open Dev menu\n"
printf " mqlaunch git          Open Git menu\n"
printf " mqlaunch tools        Open Tools menu\n"
printf " mqlaunch workflows    Open Workflows menu\n"
printf " mqlaunch release      Open Release menu\n"
printf " mqlaunch login        Open Login menu\n"
printf " mqlaunch shortcuts    Open Shortcuts menu\n"

echo -e "\n${PURPLE}STATUS / SUPPORT${NC}"
printf " mqlaunch about        Open About / Status\n"
printf " mqlaunch version      Version information\n"
printf " mqlaunch check        Run self-check\n"
printf " mqlaunch bundle       Create debug bundle\n"

echo -e "\n${PURPLE}UTILITY${NC}"
printf " mqlaunch repo         Open repo root\n"
printf " mqlaunch guide        Open terminal guide\n"
printf " mqlaunch theme        Open Themes menu\n"

echo -e "\n${BLUE}----------------------------------------------------------------------------------------${NC}"
printf "${CYAN}Host: $(scutil --get ComputerName 2>/dev/null || hostname)   User: $(whoami)${NC}\n"
printf "Time: $(date '+%Y-%m-%d %H:%M:%S')\n"
echo -e "${BLUE}----------------------------------------------------------------------------------------${NC}"
