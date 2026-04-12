#!/usr/bin/env bash

: "${C_RESET:=\033[0m}"
: "${C_BOLD:=\033[1m}"
: "${C_DIM:=\033[2m}"
: "${C_MAGENTA:=\033[35m}"
: "${C_CYAN:=\033[36m}"
: "${C_BLUE:=\033[34m}"
: "${C_WHITE:=\033[37m}"
: "${C_YELLOW:=\033[33m}"

MQ_NEON_PINK="\033[95m"
MQ_NEON_BLUE="\033[94m"
MQ_NEON_CYAN="\033[96m"
MQ_DIM_BLUE="\033[38;5;24m"
MQ_FOG="\033[38;5;250m"

mq_bg_bladerunner() {
  cat <<EOF
${MQ_NEON_BLUE}┌──────────────────────────────────────────────────────────────────────────────┐${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}          ${MQ_NEON_PINK}${C_BOLD}B L A D E   R U N N E R${C_RESET} ${MQ_FOG}/${C_RESET} ${MQ_NEON_CYAN}N E O N   B I L L B O A R D${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}├──────────────────────────────────────────────────────────────────────────────┤${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                        ${MQ_DIM_BLUE}______________________________${C_RESET}                        ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                       ${MQ_DIM_BLUE}/|${C_RESET}  ${MQ_FOG}.------------------------.${C_RESET} ${MQ_DIM_BLUE}|\\${C_RESET}                       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                      ${MQ_DIM_BLUE}/ |${C_RESET}  ${MQ_NEON_PINK}|    S E C T O R - 9     |${C_RESET} ${MQ_DIM_BLUE}| \\${C_RESET}                      ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                     ${MQ_DIM_BLUE}/  |${C_RESET}  ${MQ_NEON_CYAN}|      NIGHT GRID        |${C_RESET} ${MQ_DIM_BLUE}|  \\${C_RESET}                     ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                    ${MQ_DIM_BLUE}/   |${C_RESET}  ${MQ_FOG}'------------------------'${C_RESET} ${MQ_DIM_BLUE}|   \\${C_RESET}                    ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                   ${MQ_DIM_BLUE}/    |${C_RESET}   ${MQ_NEON_BLUE}_    _    _    _    _${C_RESET}    ${MQ_DIM_BLUE}|    \\${C_RESET}                   ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                  ${MQ_DIM_BLUE}/     |${C_RESET}  ${MQ_NEON_CYAN}|_|  |_|  |_|  |_|  |_|${C_RESET}   ${MQ_DIM_BLUE}|     \\${C_RESET}                  ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                 ${MQ_DIM_BLUE}/      |${C_RESET}  ${MQ_FOG}| |  | |  | |  | |  | |${C_RESET}   ${MQ_DIM_BLUE}|      \\${C_RESET}                 ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}  ${MQ_NEON_PINK}| |==| |==| |==| |==| |${C_RESET}   ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}  ${MQ_NEON_CYAN}| |||||||||||||||||||||${C_RESET}   ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}  ${MQ_NEON_CYAN}| |||||||||||||||||||||${C_RESET}   ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}  ${MQ_NEON_PINK}| |==| |==| |==| |==| |${C_RESET}   ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}  ${MQ_NEON_BLUE}|_|__|_|__|_|__|_|__|_|${C_RESET}   ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}     ${MQ_FOG}N E O N   C I T Y${C_RESET}      ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}       ${MQ_DIM_BLUE}|_____________________________|${C_RESET}       ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}      ${MQ_DIM_BLUE}/_______________________________\\${C_RESET}      ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|${C_RESET}     ${MQ_DIM_BLUE}/ / / / / / / / / / / / / / / / /${C_RESET}  ${MQ_DIM_BLUE}\\${C_RESET}     ${MQ_DIM_BLUE}|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                ${MQ_DIM_BLUE}|____/___________________________________\\____|${C_RESET}                ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}          ${MQ_DIM_BLUE}| |${C_RESET}        ${MQ_DIM_BLUE}| |${C_RESET}      ${MQ_DIM_BLUE}| |${C_RESET}         ${MQ_DIM_BLUE}| |${C_RESET}       ${MQ_DIM_BLUE}| |${C_RESET}         ${MQ_DIM_BLUE}| |${C_RESET}          ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}          ${MQ_DIM_BLUE}| |${C_RESET}   ${MQ_NEON_BLUE}_${C_RESET}    ${MQ_DIM_BLUE}| |${C_RESET}  ${MQ_NEON_BLUE}_${C_RESET}   ${MQ_DIM_BLUE}| |${C_RESET}    ${MQ_NEON_BLUE}_${C_RESET}    ${MQ_DIM_BLUE}| |${C_RESET}   ${MQ_NEON_BLUE}_${C_RESET}   ${MQ_DIM_BLUE}| |${C_RESET}   ${MQ_NEON_BLUE}_${C_RESET}     ${MQ_DIM_BLUE}| |${C_RESET}          ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_DIM_BLUE}.--| |--|_|---| |-|_|--| |---|_|---| |--|_|--| |--|_|----| |--.${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_DIM_BLUE}|  |_|  |_|   |_| |_|  |_|   |_|   |_|  |_|  |_|  |_|    |_|  |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_FOG}|  _   _________   ____   _________   _______   ____   _      |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_FOG}| | | |  _   _  | |    | |  _   _  | |  _   | |    | | |     |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_FOG}| | | | |_| |_| | | || | | |_| |_| | | |_|  | | || | | |     |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_FOG}| |_| |  _   _  | | || | |  _   _  | |  _   | | || | | |__   |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}       ${MQ_FOG}|_____|_| |_| |_| |____| |_| |_| |_| |_| |__| |____| |____|  |${C_RESET}       ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_NEON_PINK}::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}   ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_NEON_CYAN}::  RAIN FIELD  ::  BILLBOARD GLARE  ::  SKY TRAFFIC  ::  FOG INDEX  ::${C_RESET}   ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_NEON_PINK}::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::${C_RESET}   ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_FOG}\ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \${C_RESET}    ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}    ${MQ_DIM_BLUE}\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_${C_RESET}   ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_NEON_CYAN}DISTRICT${C_RESET}   : SECTOR 9           ${MQ_NEON_PINK}SIGNAL${C_RESET}     : GLOW THROUGH STATIC          ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_NEON_CYAN}STATUS${C_RESET}     : NIGHT TRAFFIC      ${MQ_NEON_PINK}SKY MODE${C_RESET}   : PERMANENT AFTERHOURS         ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}   ${MQ_YELLOW}${C_BOLD}>>>${C_RESET} ${MQ_FOG}SPINNER LANES ABOVE // AD BOARD BURN-IN // LOW VISIBILITY //${C_RESET}          ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}│${C_RESET}                                                                              ${MQ_NEON_BLUE}│${C_RESET}
${MQ_NEON_BLUE}└──────────────────────────────────────────────────────────────────────────────┘${C_RESET}
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  mq_bg_bladerunner "$@"
fi
