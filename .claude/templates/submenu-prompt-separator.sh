#!/usr/bin/env bash
# Template: submenu prompt with separator lines
#
# Problem: nested submenus (called from within another menu_loop) cannot
# rely on read_main_choice to draw ─── separator lines. The function either
# draws them off-screen or not at all in the nested context.
#
# Solution: pre-draw the full prompt block (top sep + prompt + bottom sep)
# then use \033[2A cursor repositioning to place vared between them.
# Both lines are visible WHILE the user types, not after.
#
# Reference fix: terminal/menus/mq-tools-menu.sh document_functions_menu_loop
# Commit: 2190d1a

# --- print function ---
# End the menu print function with printf '\n' (blank line), not a separator.
#
#   print_NAME_menu() {
#     local width panel_color
#     width="$(surface_terminal_width)"
#     panel_color="$(surface_panel_color)"
#     MQ_SURFACE_WIDTH="$width"
#
#     clear_screen
#     surface_panel_header "Title" "LABEL" "$width" "$panel_color"
#     # ... surface_row / surface_split_row calls ...
#     surface_bottom "$width" "$panel_color"
#     printf '\n'
#   }

# --- menu loop ---
# Replace read_main_choice with explicit separator + vared block.
#
#   NAME_menu_loop() {
#     local choice sep_width sep_color sep
#
#     while true; do
#       print_NAME_menu
#       sep_width="${MQ_SURFACE_WIDTH:-$(surface_terminal_width)}"
#       sep_color="$(surface_panel_color)"
#       sep="$(repeat_char "$sep_width" '─')"
#
#       printf '%b%s%b\n' "$sep_color" "$sep" "${C_RESET:-}"      # top separator
#       printf '%bLABEL > %b\n' "${C_TITLE:-}" "${C_RESET:-}"     # prompt placeholder
#       printf '%b%s%b\n' "$sep_color" "$sep" "${C_RESET:-}"      # bottom separator
#       printf '\033[2A\r'                                          # cursor up 2 → prompt line
#       printf '%bLABEL > %b' "${C_TITLE:-}" "${C_RESET:-}"       # overwrite prompt (no \n)
#
#       choice=""
#       if [[ -n "${ZSH_VERSION:-}" && -t 0 && -t 1 ]]; then
#         vared -p "" -c choice
#         printf '\033[1B\r\n'                                     # cursor down 1 → past bottom sep
#       else
#         read -r choice
#         printf '\033[1B\r\n'
#       fi
#       echo
#
#       case "$choice" in
#         1) action_one ;;
#         b|B) break ;;
#         *) ui_err "Invalid option."; pause_enter ;;
#       esac
#     done
#   }
