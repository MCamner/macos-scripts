show_command_index() {
  print_header
  row_bold "COMMAND INDEX"
  empty_row

  row "START"
  row " mqlaunch              Open main menu"
  row " mqlaunch demo         Run guided demo mode"
  row " mqlaunch help         Show help"
  row " mqlaunch commands     Show command index"
  row " mqlaunch palette      Open fuzzy command palette"

  empty_row
  row "WORKFLOWS"
  row " mqlaunch system       Open System menu"
  row " mqlaunch perf         Open Performance menu"
  row " mqlaunch dev          Open Dev menu"
  row " mqlaunch git          Open Git menu"
  row " mqlaunch tools        Open Tools menu"
  row " mqlaunch workflows    Open Workflows menu"
  row " mqlaunch release      Open Release menu"
  row " mqlaunch login        Open Login menu"
  row " mqlaunch shortcuts    Open Shortcuts menu"

  empty_row
  row "PROJECT FLOWS"
  row " mqlaunch workflows boot        Run project boot"
  row " mqlaunch workflows check       Run project check"
  row " mqlaunch login menu            Session boot + full menu"
  row " mqlaunch login about           Session boot + about screen"
  row " mqlaunch login check           Session boot + self-check"
  row " mqlaunch shortcuts list        List shortcuts directly"
  row " mqlaunch shortcuts search clip Search shortcuts by name"

  empty_row
  row "SECURITY & OPS"
  row " mqlaunch ghost        Run network cloaking (MAC/DNS spoof)"
  row " mqlaunch pulse        Diagnostic for network latency & WiFi"
  row " mqlaunch scan         Matrix-style system & port scan"
  row " mqlaunch reap         Overseer process reaper (CPU/MEM focus)"
  row " mqlaunch guard        Perimeter watchdog (USB/Power monitor)"
  row " mqlaunch mc           Open advanced system dashboard"

  empty_row
  row "CHECKS & SUPPORT"
  row " mqlaunch check        Run environment check"
  row " mqlaunch self-check   Run internal smoke test"
  row " mqlaunch bundle       Create debug bundle"
  row " mqlaunch about        Open About / Status"
  row " mqlaunch version      Show version information"
  row " mqlaunch notes        Show release notes / changelog"

  empty_row
  row "UTILITY"
  row " mqlaunch repo         Open repo root"
  row " mqlaunch guide        Open terminal guide"
  row " mqlaunch system time  Show date and time"
  row " mqlaunch theme        Open Themes menu"
  row " mqlaunch theme-macos  Apply macOS theme"
  row " mqlaunch theme-reset  Reset theme"

  print_footer
  pause_enter
}

show_help() {
  cat <<'HELP'
mqlaunch — modular terminal workflow hub

START
  mqlaunch                Open main menu
  mqlaunch demo           Run guided demo mode
  mqlaunch help           Show help
  mqlaunch commands       Show command index
  mqlaunch palette        Open fuzzy command palette

WORKFLOWS
  mqlaunch system         Open System menu
  mqlaunch perf           Open Performance menu
  mqlaunch dev            Open Dev menu
  mqlaunch git            Open Git menu
  mqlaunch tools          Open Tools menu
  mqlaunch workflows      Open Workflows menu
  mqlaunch release        Open Release menu
  mqlaunch login          Open Login menu
  mqlaunch shortcuts      Open Shortcuts menu

PROJECT FLOWS
  mqlaunch workflows boot        Run project boot
  mqlaunch workflows check       Run project check
  mqlaunch login menu            Session boot + full menu
  mqlaunch login about           Session boot + about screen
  mqlaunch login check           Session boot + self-check
  mqlaunch shortcuts list        List shortcuts directly
  mqlaunch shortcuts search clip Search shortcuts by name

SECURITY & OPS
  mqlaunch ghost          Run network cloaking (MAC/DNS spoof)
  mqlaunch pulse          Diagnostic for network latency & WiFi
  mqlaunch scan           Matrix-style system & port scan
  mqlaunch reap           Overseer process reaper (CPU/MEM focus)
  mqlaunch guard          Perimeter watchdog (USB/Power monitor)
  mqlaunch mc             Open advanced system dashboard

CHECKS & SUPPORT
  mqlaunch check          Run environment check
  mqlaunch self-check     Run internal smoke test
  mqlaunch bundle         Create debug bundle
  mqlaunch about          Open About / Status
  mqlaunch version        Show version information
  mqlaunch notes          Show release notes / changelog

UTILITY
  mqlaunch repo           Open repo root
  mqlaunch guide          Open terminal guide
  mqlaunch system time    Show date and time
  mqlaunch theme          Open Themes menu
  mqlaunch theme-macos    Apply macOS theme
  mqlaunch theme-reset    Reset theme

POPULAR FLOWS
  mqlaunch
  mqlaunch perf
  mqlaunch system check
  mqlaunch doctor
  mqlaunch dev
  mqlaunch tools
HELP
}
