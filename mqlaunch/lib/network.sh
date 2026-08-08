#!/bin/zsh
# mqlaunch network concern — status, diagnostics, and connectivity actions.
#
# Extracted from terminal/launchers/mqlaunch.sh as part of Step 11a (monolith
# de-layering, audit P4). This file is *sourced into the launcher's scope*, so
# it deliberately relies on the launcher's ambient UI helpers (print_header,
# row, empty_row, print_footer, pause_enter), colour vars (C_ERR/C_RESET), and
# $BASE_DIR. It defines no state of its own and changes no behavior — the
# functions are verbatim moves. Uses zsh builtins (print -r --), so it carries a
# zsh shebang and is syntax-checked with `zsh -n`.

# Reads the default route interface used for active network traffic.
network_default_interface() {
  local iface
  iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
  [[ -n "$iface" ]] && print -r -- "$iface"
}

# Finds the macOS network service name for an interface.
network_service_name() {
  local iface="$1"
  networksetup -listallhardwareports 2>/dev/null | awk -v iface="$iface" '
    /^Hardware Port: / {
      sub(/^Hardware Port: /, "")
      port=$0
    }
    /^Device: / {
      sub(/^Device: /, "")
      if ($0 == iface) {
        print port
        exit
      }
    }
  '
}

# Reads an IPv4 address for a network interface.
network_interface_ip() {
  local iface="$1"
  [[ -n "$iface" ]] || return 1
  ipconfig getifaddr "$iface" 2>/dev/null || true
}

# Reads the first configured DNS server.
network_dns_server() {
  scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3; exit}'
}

# Reads the default gateway.
network_gateway() {
  route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}'
}

# Reads the current Wi-Fi SSID when the active service supports it.
network_ssid() {
  local iface="$1"
  local service="${2:-}"
  [[ -n "$iface" ]] || return 1
  [[ "$service" == *"Wi-Fi"* || "$service" == *"AirPort"* ]] || return 1
  networksetup -getairportnetwork "$iface" 2>/dev/null | sed 's/^Current Wi-Fi Network: //'
}

# Measures a single ping and returns the average latency.
network_ping_ms() {
  local host="$1"
  [[ -n "$host" ]] || return 1
  ping -c 1 -W 1000 "$host" 2>/dev/null | awk -F'/' '/round-trip|rtt/ {print $5 " ms"; exit}'
}

# Converts an empty network value into a readable status.
network_value() {
  local value="$1"
  local fallback="${2:-Not found}"
  if [[ -n "$value" ]]; then
    print -r -- "$value"
  else
    print -r -- "$fallback"
  fi
}

# Builds a compact network status report.
network_report() {
  local iface service ip gateway dns ssid gateway_ms internet_ms internet_status
  iface="$(network_default_interface)"
  service="$(network_service_name "$iface")"
  ip="$(network_interface_ip "$iface")"
  gateway="$(network_gateway)"
  dns="$(network_dns_server)"
  ssid="$(network_ssid "$iface" "$service")"

  if [[ -n "$gateway" ]]; then
    gateway_ms="$(network_ping_ms "$gateway")"
  fi
  internet_ms="$(network_ping_ms "1.1.1.1")"

  if [[ -n "$internet_ms" ]]; then
    internet_status="Reachable ($internet_ms)"
  else
    internet_status="Not reachable"
  fi

  cat <<EOF
Active:  $(network_value "$iface" "No default interface") ($(network_value "$service" "unknown service"))
IP:      $(network_value "$ip" "No active IPv4 address")
Gateway: $(network_value "$gateway")
DNS:     $(network_value "$dns")
SSID:    $(network_value "$ssid" "Not Wi-Fi or unavailable")
Gateway latency:  $(network_value "$gateway_ms" "Not tested")
Internet: $internet_status
EOF
}

# Copies network info.
copy_network_info() {
  local payload
  payload="$(network_report)"

  if command -v pbcopy >/dev/null 2>&1; then
    print -r -- "$payload" | pbcopy
    print_header
    row "COPY NETWORK INFO"
    empty_row
    while IFS= read -r line; do
      row "$line"
    done <<< "$payload"
    print_footer
    pause_enter
  else
    echo "${C_ERR}pbcopy missing.${C_RESET}"
    pause_enter
  fi
}

# Opens network settings.
open_network_settings() {
  print_header
  row "OPEN NETWORK SETTINGS"
  empty_row
  row "Opening System Settings → Network"
  print_footer
  open "x-apple.systempreferences:com.apple.Network-Settings.extension"
}

# Runs a short connectivity test against common network targets.
ping_test() {
  local gateway gateway_ms cloudflare_ms google_ms
  gateway="$(network_gateway)"
  gateway_ms="$(network_ping_ms "$gateway")"
  cloudflare_ms="$(network_ping_ms "1.1.1.1")"
  google_ms="$(network_ping_ms "8.8.8.8")"

  print_header
  row "CONNECTIVITY TEST"
  empty_row
  row "Gateway:    $(network_value "$gateway_ms" "Not reachable")"
  row "Cloudflare: $(network_value "$cloudflare_ms" "Not reachable")"
  row "Google DNS: $(network_value "$google_ms" "Not reachable")"
  empty_row
  print_footer
  pause_enter
}

# Shows dns gateway.
show_dns_gateway() {
  local gateway dns
  gateway="$(route -n get default 2>/dev/null | awk '/gateway:/{print $2; exit}')"
  dns="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3; exit}')"
  [[ -z "$gateway" ]] && gateway="-"
  [[ -z "$dns" ]] && dns="-"

  print_header
  row "DNS + GATEWAY"
  empty_row
  row "Gateway: $gateway"
  row "DNS:     $dns"
  print_footer
  pause_enter
}

# Runs network pulse diagnostics.
#
# Through the dispatcher, not tools/scripts/pulse.sh. Unlike `doctor`, the pulse
# and ghost routes end in `return $?` without a pause of their own, so the
# pause_enter stays here — dropping it would return straight to the menu and
# repaint over the output.
run_network_pulse() {
  "$BASE_DIR/bin/mqlaunch" pulse
  pause_enter
}

# Runs network ghost diagnostics and cloaking actions.
run_network_ghost() {
  "$BASE_DIR/bin/mqlaunch" ghost
  pause_enter
}

# Runs macOS networkQuality when available.
run_network_quality() {
  print_header
  row "NETWORK QUALITY"
  empty_row

  if command -v networkQuality >/dev/null 2>&1; then
    networkQuality
  else
    row "networkQuality is not available on this macOS version."
  fi

  print_footer
  pause_enter
}

# Shows network info.
show_network_info() {
  local report

  report="$(network_report)"
  print_header
  row "NETWORK OVERVIEW"
  empty_row
  while IFS= read -r line; do
    row "$line"
  done <<< "$report"
  print_footer
  pause_enter
}
