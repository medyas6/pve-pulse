#!/usr/bin/env bash
# pve-pulse - a small terminal UI to manage a Proxmox VE homelab.
# List VMs/CTs, power actions, snapshots, backups, a creation wizard
# and a node dashboard. Works against the local node, the Proxmox API,
# or in demo mode with fake data.
#
# Author: Mohamed Yassine (github.com/medyas6)
# License: MIT

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- load libraries -----------------------------------------------------------
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/backend.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/guests.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/snapshots.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/wizard.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/backups.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/dashboard.sh"
# demo dataset (only used when the demo backend is active, tiny anyway)
# shellcheck source=/dev/null
. "$SCRIPT_DIR/demo/demo-data.sh"

# --- usage ------------------------------------------------------------------
print_usage() {
    cat <<EOF
Usage: pve-pulse.sh [OPTIONS]

A terminal UI for managing Proxmox VE guests (VMs and containers).

Options:
  --demo        force the demo backend (fake data, nothing is touched)
  --json        print the guest list as JSON and exit (scripting friendly)
  --no-color    disable colored output
  --help        show this help and exit
  --version     print the version and exit

Backends (auto-detected, or set PVE_BACKEND in the config file):
  local   run qm/pct/pvesh on the Proxmox node itself
  api     talk to https://PVE_HOST:8006 via API token (see config.example)
  demo    fake data, every write action is only simulated

Config:  ~/.config/pve-pulse/config   (see config.example)
Log:     ~/.local/share/pve-pulse/actions.log

Examples:
  ./pve-pulse.sh --demo        # try everything safely
  ./pve-pulse.sh --demo --json # guest list as JSON
EOF
}

# --- argument parsing ---------------------------------------------------------
DO_JSON=0

while [ $# -gt 0 ]; do
    case "$1" in
        --demo)     PVE_DEMO=1 ;;
        --json)     DO_JSON=1 ;;
        --no-color) PVE_PULSE_COLORS=0 ;;
        --help|-h)  print_usage; exit 0 ;;
        --version|-v) printf 'pve-pulse %s\n' "$PVE_PULSE_VERSION"; exit 0 ;;
        *) die "unknown option: $1 (try --help)" 2 ;;
    esac
    shift
done

# --- init ---------------------------------------------------------------------
color_init
load_config
log_init
backend_detect

# --- non-interactive modes ----------------------------------------------------
if [ "$DO_JSON" -eq 1 ]; then
    list_guests --json
    exit 0
fi

# --- guest actions submenu ----------------------------------------------------
guest_actions_menu() {
    while true; do
        clear_screen
        header "Guest actions"
        local choice
        choice="$(menu "Action" \
            "Start a guest" \
            "Stop a guest" \
            "Restart a guest" \
            "Show IP addresses" \
            "Open console" \
            "Back")" || return 0
        case "$choice" in
            1) guest_power start;   pause ;;
            2) guest_power stop;    pause ;;
            3) guest_power restart; pause ;;
            4) guest_ips_show;      pause ;;
            5) guest_console ;;
            6) return 0 ;;
        esac
    done
}

# --- bulk submenu ---------------------------------------------------------------
bulk_menu() {
    while true; do
        clear_screen
        header "Bulk actions"
        local choice
        choice="$(menu "Action" \
            "Start all stopped guests" \
            "Stop all running guests" \
            "Back")" || return 0
        case "$choice" in
            1) bulk_action start; pause ;;
            2) bulk_action stop;  pause ;;
            3) return 0 ;;
        esac
    done
}

# --- settings -------------------------------------------------------------------
settings_show() {
    clear_screen
    header "Settings"
    draw_box "pve-pulse $PVE_PULSE_VERSION" \
        "backend:  $(backend_label)" \
        "PVE_HOST: ${PVE_HOST:-<not set>}" \
        "PVE_NODE: ${PVE_NODE:-<not set>}" \
        "token:    $([ -n "$PVE_TOKEN" ] && echo '<set>' || echo '<not set>')" \
        "colors:   $([ "$PVE_PULSE_COLORS" = "1" ] && echo on || echo off)"
    printf '\n'
    config_hint
}

log_view() {
    clear_screen
    header "Action log"
    if [ -s "$PVE_PULSE_LOG_FILE" ]; then
        tail -n 40 "$PVE_PULSE_LOG_FILE"
    else
        info "Log is empty. Actions you take will show up here."
    fi
    printf '\nLog file: %s\n' "$PVE_PULSE_LOG_FILE"
}

# --- main menu --------------------------------------------------------------------
main_menu() {
    while true; do
        clear_screen
        banner
        header "Main menu"
        printf '  %s1)%s List guests\n'        "$C_BOLD" "$C_RESET"
        printf '  %s2)%s Guest actions (start/stop/console/...)\n' "$C_BOLD" "$C_RESET"
        printf '  %s3)%s Snapshots\n'          "$C_BOLD" "$C_RESET"
        printf '  %s4)%s Create VM/CT wizard\n' "$C_BOLD" "$C_RESET"
        printf '  %s5)%s Backups\n'           "$C_BOLD" "$C_RESET"
        printf '  %s6)%s Node dashboard\n'    "$C_BOLD" "$C_RESET"
        printf '  %s7)%s Bulk actions\n'      "$C_BOLD" "$C_RESET"
        printf '  %s8)%s View action log\n'   "$C_BOLD" "$C_RESET"
        printf '  %s9)%s Settings\n'          "$C_BOLD" "$C_RESET"
        printf '  %s0)%s Quit\n'              "$C_BOLD" "$C_RESET"
        printf '\nchoice > ' >&2
        local c
        IFS= read -r c || { printf '\n'; break; }   # Ctrl+D quits
        case "$c" in
            1) list_guests; pause ;;
            2) guest_actions_menu ;;
            3) snap_menu ;;
            4) wizard; pause ;;
            5) backups_menu ;;
            6) dashboard; pause ;;
            7) bulk_menu ;;
            8) log_view; pause ;;
            9) settings_show; pause ;;
            0|q|Q) break ;;
            '') ;;                                    # empty: redraw
            *) warn "invalid choice: $c" ;;
        esac
    done
    printf 'bye.\n'
}

main_menu
