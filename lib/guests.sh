# pve-pulse - lib/guests.sh
# Guest (VM/CT) operations: listing, power actions, console, IPs, bulk actions.
#
# Author: Mohamed Yassi (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_GUESTS_SH:-}" ] && return 0
_PVE_PULSE_GUESTS_SH=1

# GUESTS_CACHE holds the last backend_list_guests result (array of records).
GUESTS_CACHE=()

guests_refresh() {
    # guests_refresh -- reload guest list from the active backend
    GUESTS_CACHE=()
    local line
    while IFS= read -r line; do
        [ -n "$line" ] && GUESTS_CACHE+=("$line")
    done < <(backend_list_guests)
}

guest_field() {
    # guest_field <record> <n> -- print field n of a pipe-separated record,
    # trimmed (demo data is padded for readability, real CLI output too)
    local rec="$1" n="$2"
    trim "$(printf '%s' "$rec" | cut -d'|' -f"$n")"
}

guests_count_by_status() {
    # guests_count_by_status <status> -- echo number of guests with status
    local want="$1" n=0 g st
    for g in "${GUESTS_CACHE[@]}"; do
        st="$(guest_field "$g" 4)"
        [ "$st" = "$want" ] && n=$((n+1))
    done
    printf '%d' "$n"
}

# ---------------------------------------------------------------------------
# list_guests [--json]
# ---------------------------------------------------------------------------
list_guests() {
    guests_refresh
    if [ "${1:-}" = "--json" ]; then
        guests_print_json
        return 0
    fi
    if [ "${#GUESTS_CACHE[@]}" -eq 0 ]; then
        warn "No guests found on this backend."
        return 0
    fi
    {
        printf 'ID|TYPE|NAME|STATUS|NODE|CPUs|RAM MB|DISK GB|IP\n'
        local g type vmid name status node cpus ram disk ip
        for g in "${GUESTS_CACHE[@]}"; do
            type="$(guest_field "$g" 1)"; vmid="$(guest_field "$g" 2)"
            name="$(guest_field "$g" 3)"; status="$(guest_field "$g" 4)"
            node="$(guest_field "$g" 5)"; cpus="$(guest_field "$g" 6)"
            ram="$(guest_field "$g" 7)";  disk="$(guest_field "$g" 8)"
            ip="$(guest_field "$g" 9)"
            printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
                "$vmid" "$type" "$name" "$status" "${node:--}" \
                "${cpus:--}" "${ram:--}" "${disk:--}" "${ip:--}"
        done
    } | print_table
    printf '\nTotal: %d guests (%d running, %d stopped)\n' \
        "${#GUESTS_CACHE[@]}" \
        "$(guests_count_by_status running)" \
        "$(guests_count_by_status stopped)"
}

guests_print_json() {
    # JSON array of guest objects (automation-ready)
    local g first=1 type vmid name status node cpus ram disk ip
    printf '[\n'
    for g in "${GUESTS_CACHE[@]}"; do
        type="$(guest_field "$g" 1)"; vmid="$(guest_field "$g" 2)"
        name="$(guest_field "$g" 3)"; status="$(guest_field "$g" 4)"
        node="$(guest_field "$g" 5)"; cpus="$(guest_field "$g" 6)"
        ram="$(guest_field "$g" 7)";  disk="$(guest_field "$g" 8)"
        ip="$(guest_field "$g" 9)"
        [ "$first" -eq 1 ] || printf ',\n'
        first=0
        printf '  {"type":"%s","vmid":"%s","name":"%s","status":"%s","node":"%s","cpus":"%s","ram_mb":"%s","disk_gb":"%s","ip":"%s"}' \
            "$(json_escape "$type")" "$(json_escape "$vmid")" "$(json_escape "$name")" \
            "$(json_escape "$status")" "$(json_escape "$node")" "$cpus" "$ram" "$disk" \
            "$(json_escape "$ip")"
    done
    printf '\n]\n'
}

json_escape() {
    # json_escape <string> -- escape backslashes and double quotes for JSON
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Interactive guest picker: pick_guest [prompt] -- echoes "type|vmid|name"
# ---------------------------------------------------------------------------
pick_guest() {
    local prompt="${1:-Select a guest}" g type vmid name status opts=()
    guests_refresh
    [ "${#GUESTS_CACHE[@]}" -eq 0 ] && { warn "No guests available."; return 1; }
    local idx=0
    for g in "${GUESTS_CACHE[@]}"; do
        type="$(guest_field "$g" 1)"; vmid="$(guest_field "$g" 2)"
        name="$(guest_field "$g" 3)"; status="$(guest_field "$g" 4)"
        idx=$((idx+1))
        opts+=("[$type] $vmid - $name ($status)")
    done
    opts+=("Cancel")
    local choice
    choice="$(menu "$prompt" "${opts[@]}")" || return 1
    if [ "$choice" -eq "$((idx+1))" ]; then
        return 1  # Cancel
    fi
    g="${GUESTS_CACHE[$((choice-1))]}"
    printf '%s|%s|%s\n' "$(guest_field "$g" 1)" "$(guest_field "$g" 2)" "$(guest_field "$g" 3)"
}

# ---------------------------------------------------------------------------
# Power actions
# ---------------------------------------------------------------------------
guest_power() {
    # guest_power <action> -- interactive: pick guest, confirm, run
    local action="$1" sel type vmid name
    sel="$(pick_guest "Guest to $action")" || return 0
    type="${sel%%|*}"; rest="${sel#*|}"; vmid="${rest%%|*}"; name="${rest#*|}"
    if ! confirm "$action $type $vmid ($name)?"; then
        info "Cancelled."
        return 0
    fi
    info "Running: $action $type $vmid ..."
    if backend_guest_action "$action" "$type" "$vmid"; then
        ok "Done."
        log_action "$action" "$type $vmid ($name)"
    else
        warn "Action failed (see Proxmox task log for details)."
        log_action "${action}-FAILED" "$type $vmid ($name)"
    fi
}

guest_ips_show() {
    local sel type vmid name ips
    sel="$(pick_guest "Show IPs for")" || return 0
    type="${sel%%|*}"; rest="${sel#*|}"; vmid="${rest%%|*}"; name="${rest#*|}"
    info "IP addresses of $type $vmid ($name):"
    ips="$(backend_guest_ips "$type" "$vmid")"
    if [ -n "$ips" ]; then
        printf '%s\n' "$ips" | sed 's/^/  - /'
    else
        warn "No IP info (guest may be stopped or qemu-guest-agent missing)."
    fi
}

guest_console() {
    local sel type vmid name hint
    sel="$(pick_guest "Open console for")" || return 0
    type="${sel%%|*}"; rest="${sel#*|}"; vmid="${rest%%|*}"; name="${rest#*|}"
    hint="$(backend_console_hint "$type" "$vmid")"
    log_action "console" "$type $vmid ($name)"
    if [ "$PVE_ACTIVE_BACKEND" = "local" ]; then
        info "Attaching console (Ctrl+O then Q to detach from qm terminal)..."
        # shellcheck disable=SC2086 - intentional word splitting of known-safe cmd
        exec $hint
    else
        info "$hint"
    fi
}

# ---------------------------------------------------------------------------
# Bulk actions (NEW): start-all / stop-all with confirmation
# ---------------------------------------------------------------------------
bulk_action() {
    # bulk_action <start|stop>
    local action="$1" g type vmid name status count=0
    guests_refresh
    for g in "${GUESTS_CACHE[@]}"; do
        status="$(guest_field "$g" 4)"
        if { [ "$action" = "start" ] && [ "$status" = "stopped" ]; } || \
           { [ "$action" = "stop"  ] && [ "$status" = "running" ]; }; then
            count=$((count+1))
        fi
    done
    if [ "$count" -eq 0 ]; then
        info "Nothing to $action (no matching guests)."
        return 0
    fi
    warn "This will $action $count guest(s)."
    if ! confirm_typed "Proceed with bulk $action?"; then
        info "Cancelled."
        return 0
    fi
    for g in "${GUESTS_CACHE[@]}"; do
        type="$(guest_field "$g" 1)"; vmid="$(guest_field "$g" 2)"
        name="$(guest_field "$g" 3)"; status="$(guest_field "$g" 4)"
        if { [ "$action" = "start" ] && [ "$status" = "stopped" ]; } || \
           { [ "$action" = "stop"  ] && [ "$status" = "running" ]; }; then
            printf '  %sing %s %s (%s)... ' "$action" "$type" "$vmid" "$name"
            if backend_guest_action "$action" "$type" "$vmid" >/dev/null 2>&1; then
                printf '%sok%s\n' "$C_GREEN" "$C_RESET"
                log_action "bulk-$action" "$type $vmid ($name)"
            else
                printf '%sFAILED%s\n' "$C_RED" "$C_RESET"
                log_action "bulk-${action}-FAILED" "$type $vmid ($name)"
            fi
        fi
    done
    ok "Bulk $action finished."
}
