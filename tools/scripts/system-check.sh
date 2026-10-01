#!/bin/zsh

# Print a best-effort macOS system snapshot without changing settings.
# The exit status is not an aggregate health result; failed checks do not stop the report.

echo "=========================================="
echo "         SYSTEM CHECK (macOS)"
echo "=========================================="
echo

echo "Computer name:"
scutil --get ComputerName 2>/dev/null || echo "Unavailable"
echo

echo "Local hostname:"
scutil --get LocalHostName 2>/dev/null || echo "Unavailable"
echo

echo "Current user:"
whoami
echo

echo "macOS version:"
sw_vers
echo

echo "Uptime:"
uptime
echo

echo "Disk usage:"
df -h /
echo

echo "Memory pressure:"
memory_pressure 2>/dev/null | head -n 10
echo

echo "Battery:"
pmset -g batt 2>/dev/null || echo "No battery info available"
echo

echo "Wi-Fi / IP:"
# Probe en0, then en1, for IPv4; these interface names do not identify Wi-Fi.
# The first successful result need not belong to the default-route interface.
ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "No active Wi-Fi IP found"
echo

echo "=========================================="
echo "Done."
echo "=========================================="
