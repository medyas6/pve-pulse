# pve-pulse - lib/backups.sh
# Backup operations: list vzdump archives, run a backup now, schedule hints.
#
# Author: Mohamed Yassi (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_BACKUPS_SH:-}" ] && return 0
_PVE_PULSE_BACKUPS_SH=1

backups_menu() {
    while true; do
        clear_screen
        header "Backups"
        local choice
        choice="$(menu "Backup action" \
            "List backup archives" \
            "Backup a guest now (vzdump)" \
            "Show scheduled-backup hint" \
            "Back")" || return 0
        case "$choice" in
            1) backup_list_show; pause ;;
            2) backup_now_interactive; pause ;;
            3) backup_schedule_hint; pause ;;
            4) return 0 ;;
        esac
    done
}

backup_list_show() {
    local out
    out="$(backend_backup_list)"
    if [ -z "$out" ]; then
        info "No backup archives found."
        return 0
    fi
    {
        printf 'FILE|SIZE|DATE\n'
        printf '%s\n' "$out"
    } | print_table
}

backup_now_interactive() {
    local sel type vmid name
    sel="$(pick_guest "Backup which guest?")" || return 0
    type="${sel%%|*}"; rest="${sel#*|}"; vmid="${rest%%|*}"; name="${rest#*|}"
    warn "vzdump will snapshot $type $vmid ($name). This can take a while."
    if ! confirm "Start backup now?"; then
        info "Cancelled."
        return 0
    fi
    info "Running vzdump on $type $vmid ..."
    if backend_backup_now "$type" "$vmid"; then
        ok "Backup finished."
        log_action "backup" "$type $vmid ($name)"
    else
        warn "Backup failed."
        log_action "backup-FAILED" "$type $vmid ($name)"
    fi
}

backup_schedule_hint() {
    draw_box "Scheduled backups" \
        "Proxmox schedules backups in:" \
        "  Datacenter -> Backup -> Add" \
        "" \
        "CLI equivalent:" \
        "  pvesh create /cluster/backup --storage local \\" \
        "      --schedule 'sat 02:00' --mode snapshot --compress zstd" \
        "" \
        "Tip: keep at least one weekly backup of every" \
        "important VM/CT on separate storage."
}
