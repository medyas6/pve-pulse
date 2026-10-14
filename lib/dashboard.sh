# pve-pulse - lib/dashboard.sh
# Node dashboard: hostname, uptime, CPU/RAM/disk usage bars, guest counts.
#
# Author: Mohamed Yassi (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_DASHBOARD_SH:-}" ] && return 0
_PVE_PULSE_DASHBOARD_SH=1

dashboard() {
    clear_screen
    header "Node dashboard"

    # --- node info from the backend -----------------------------------------
    local hostname="" uptime_s=0 cpu_pct="n/a"
    local ram_used=0 ram_total=1 disk_used=0 disk_total=1
    local line key val
    while IFS='=' read -r key val; do
        case "$key" in
            hostname)    hostname="$val" ;;
            uptime_s)    uptime_s="$val" ;;
            cpu_pct)     cpu_pct="$val" ;;
            ram_used_mb) ram_used="$val" ;;
            ram_total_mb) ram_total="$val" ;;
            disk_used_gb) disk_used="$val" ;;
            disk_total_gb) disk_total="$val" ;;
        esac
    done < <(backend_node_info)

    [ -z "$hostname" ] && hostname="${PVE_NODE:-unknown}"

    # --- guest counts ---------------------------------------------------------
    guests_refresh
    local total="${#GUESTS_CACHE[@]}"
    local running stopped vms cts g t
    running="$(guests_count_by_status running)"
    stopped="$(guests_count_by_status stopped)"
    vms=0; cts=0
    for g in "${GUESTS_CACHE[@]}"; do
        t="$(guest_field "$g" 1)"
        [ "$t" = "vm" ] && vms=$((vms+1)) || cts=$((cts+1))
    done

    # --- render ---------------------------------------------------------------
    printf '%sNode:%s      %s\n' "$C_BOLD" "$C_RESET" "$hostname"
    printf '%sUptime:%s    %s\n' "$C_BOLD" "$C_RESET" "$(human_uptime "${uptime_s:-0}")"
    printf '%sBackend:%s   %s\n\n' "$C_BOLD" "$C_RESET" "$(backend_label)"

    printf 'CPU   '
    if [ "$cpu_pct" = "n/a" ] || [ -z "$cpu_pct" ]; then
        printf '%sn/a%s\n' "$C_DIM" "$C_RESET"
    else
        usage_bar "${cpu_pct%.*}" 100 24; printf '\n'
    fi
    printf 'RAM   '; usage_bar "$ram_used" "$ram_total" 24
    printf '  (%s / %s MB)\n' "$ram_used" "$ram_total"
    printf 'Disk  '; usage_bar "$disk_used" "$disk_total" 24
    printf '  (%s / %s GB)\n\n' "$disk_used" "$disk_total"

    printf '%sGuests:%s  %d total  |  ' "$C_BOLD" "$C_RESET" "$total"
    printf '%s%d running%s  ' "$C_GREEN" "$running" "$C_RESET"
    printf '%s%d stopped%s  ' "$C_RED" "$stopped" "$C_RESET"
    printf '|  %d VMs  %d CTs\n' "$vms" "$cts"
}
