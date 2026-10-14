# pve-pulse - lib/snapshots.sh
# Snapshot operations: list, create, rollback, delete.
# Rollback and delete are destructive -> require typed YES confirmation.
#
# Author: Mohamed Yassi (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_SNAPSHOTS_SH:-}" ] && return 0
_PVE_PULSE_SNAPSHOTS_SH=1

snap_menu() {
    local sel type vmid name
    sel="$(pick_guest "Snapshots for which guest?")" || return 0
    type="${sel%%|*}"; rest="${sel#*|}"; vmid="${rest%%|*}"; name="${rest#*|}"

    while true; do
        clear_screen
        header "Snapshots - $type $vmid ($name)"
        snap_list_table "$type" "$vmid"
        local choice
        choice="$(menu "Snapshot action" \
            "Create snapshot" \
            "Rollback to snapshot" \
            "Delete snapshot" \
            "Back")" || return 0
        case "$choice" in
            1) snap_create "$type" "$vmid" "$name" ;;
            2) snap_rollback "$type" "$vmid" "$name" ;;
            3) snap_delete "$type" "$vmid" "$name" ;;
            4) return 0 ;;
        esac
        pause
    done
}

snap_list_table() {
    # snap_list_table <type> <vmid> -- print table of snapshots
    local type="$1" vmid="$2" out
    out="$(backend_snap_list "$type" "$vmid")"
    if [ -z "$out" ]; then
        info "No snapshots for $type $vmid."
        return 0
    fi
    {
        printf 'NAME|DESCRIPTION|DATE\n'
        printf '%s\n' "$out"
    } | print_table
}

snap_create() {
    local type="$1" vmid="$2" name="$3" snapname desc
    snapname="$(ask "Snapshot name" "snap-$(date +%Y%m%d-%H%M)")"
    [ -z "$snapname" ] && { info "Cancelled."; return 0; }
    case "$snapname" in
        *[!a-zA-Z0-9_-]*) warn "Use only letters, digits, - and _."; return 0 ;;
    esac
    desc="$(ask "Description (optional)")"
    info "Creating snapshot '$snapname' on $type $vmid ..."
    if backend_snap_action create "$type" "$vmid" "$snapname"; then
        ok "Snapshot created."
        log_action "snap-create" "$type $vmid ($name) -> $snapname ${desc:+[$desc]}"
    else
        warn "Snapshot creation failed."
        log_action "snap-create-FAILED" "$type $vmid ($name) -> $snapname"
    fi
}

snap_pick_name() {
    # snap_pick_name <type> <vmid> -- interactive snapshot picker, echoes name
    local type="$1" vmid="$2" out names=() choice
    out="$(backend_snap_list "$type" "$vmid")"
    [ -z "$out" ] && { warn "No snapshots to choose from."; return 1; }
    while IFS= read -r line; do
        names+=("$(printf '%s' "$line" | cut -d'|' -f1)")
    done <<EOF
$out
EOF
    names+=("Cancel")
    choice="$(menu "Choose snapshot" "${names[@]}")" || return 1
    [ "$choice" -eq "${#names[@]}" ] && return 1
    printf '%s\n' "${names[$((choice-1))]}"
}

snap_rollback() {
    local type="$1" vmid="$2" name="$3" snapname
    snapname="$(snap_pick_name "$type" "$vmid")" || return 0
    warn "Rollback will DISCARD all changes made after '$snapname'!"
    if ! confirm_typed "Rollback $type $vmid to '$snapname'?"; then
        info "Cancelled."
        return 0
    fi
    info "Rolling back $type $vmid to '$snapname' ..."
    if backend_snap_action rollback "$type" "$vmid" "$snapname"; then
        ok "Rollback done."
        log_action "snap-rollback" "$type $vmid ($name) -> $snapname"
    else
        warn "Rollback failed."
        log_action "snap-rollback-FAILED" "$type $vmid ($name) -> $snapname"
    fi
}

snap_delete() {
    local type="$1" vmid="$2" name="$3" snapname
    snapname="$(snap_pick_name "$type" "$vmid")" || return 0
    warn "Deleting snapshot '$snapname' is permanent!"
    if ! confirm_typed "Delete snapshot '$snapname' on $type $vmid?"; then
        info "Cancelled."
        return 0
    fi
    info "Deleting snapshot '$snapname' ..."
    if backend_snap_action delete "$type" "$vmid" "$snapname"; then
        ok "Snapshot deleted."
        log_action "snap-delete" "$type $vmid ($name) -> $snapname"
    else
        warn "Delete failed."
        log_action "snap-delete-FAILED" "$type $vmid ($name) -> $snapname"
    fi
}
