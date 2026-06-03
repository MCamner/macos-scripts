# Terminal Box Templates

Use these templates when creating or repairing mqlaunch terminal boxes.

The goal is to avoid one-off width math. Prefer shared `surface_*` helpers for
new menus. Use the `frame_*` template only when maintaining legacy launchers
that already own their own frame helpers, such as `terminal/launchers/gitlaunch.sh`.

## mqlaunch Surface Menu

Use this for new menu modules under `terminal/menus/`.

```bash
render_example_panel() {
  local width panel_color
  width="$(surface_terminal_width)"
  panel_color="$(surface_panel_color)"

  surface_panel_header "Example" "Mode" "$width" "$panel_color"
  surface_row "SECTION" "$width" "$panel_color"
  surface_split_row "1. First action" "2. Second action" "$width" "$panel_color"
  surface_split_row "3. Third action" "4. Fourth action" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_split_row "b. Back" "x. Exit launcher" "$width" "$panel_color"
  surface_row "" "$width" "$panel_color"
  surface_row "Status: ready" "$width" "$panel_color"
  surface_bottom "$width" "$panel_color"
}
```

Rules:

- Use `surface_terminal_width`; never hardcode box width.
- Use `surface_split_row`; do not draw a manual center divider.
- Keep section labels short uppercase nouns.
- Keep every option label short enough to fit at the 60-column clamp.
- Keep border color from `surface_panel_color`.

## Legacy Frame Helpers

Use this only for standalone launchers that cannot easily source `mq-ui.sh`.
This layout keeps every row exactly the same visible width as the top and bottom
borders.

```bash
UI_WIDTH=88
UI_INNER=$((UI_WIDTH - 4))

frame_two_col() {
  local left right left_width right_width
  left_width=$((UI_INNER / 2))
  right_width=$((UI_INNER - left_width - 1))
  left=$(truncate_text "$1" "$left_width")
  right=$(truncate_text "$2" "$right_width")
  printf "%b│%b %-${left_width}s %-${right_width}s %b│%b\n" \
    "$C_BORDER" "$C_RESET" "$left" "$right" "$C_BORDER" "$C_RESET"
}

fallback_status_row() {
  local label="$1"
  local value="$2"
  local color="${3:-}"
  local label_width=8
  local value_width
  update_ui_width
  value_width=$((UI_INNER - 10))
  (( value_width < 1 )) && value_width=1
  value=$(truncate_text "$value" "$value_width")
  printf "%b│%b %b%-${label_width}s%b: %b%-${value_width}s%b %b│%b\n" \
    "$C_BORDER" "$C_RESET" "$C_TITLE" "$label" "$C_RESET" "$color" "$value" "$C_RESET" "$C_BORDER" "$C_RESET"
}
```

Rules:

- `UI_INNER` is `UI_WIDTH - 4` because each row has border, space, text, space, border.
- Two-column rows should contain one outer box, not two nested boxes.
- `left_width + 1 + right_width` must equal `UI_INNER`.
- For status rows, `label_width + colon + space + value_width` must equal `UI_INNER`.
- If the prompt accepts `b`, the helper text must say so.
- In non-interactive tests, EOF should exit/back instead of looping on `Invalid`.

## Visual Target

```text
┌─ Gitlaunch ──────────────────────────────────────────────────────────────────┐
│ Host: Zephyr   User: mansys   Repo: macos-scripts   Branch: main             │
│ Git: Clean   Staged: 0   Unstaged: 0   Untracked: 0                          │
├──────────────────────────────────────────────────────────────────────────────┤
│ 1. Git status                          2. Pull                               │
│ 3. Suggest commit                      4. Safe push                          │
│ 5. Open repo                           6. Dev mode                           │
│ 7. Switch repo                         8. Auto commit + push                 │
│ 9. Recent log                          b. Back                               │
└──────────────────────────────────────────────────────────────────────────────┘
```
