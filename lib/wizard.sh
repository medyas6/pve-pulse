# pve-pulse - lib/wizard.sh
# Interactive VM / CT creation wizard.
# Builds a `qm create` / `pct create` command, shows a preview,
# asks for confirmation, then executes (demo backend: simulates).
#
# Author: Mohamed Yassine (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_WIZARD_SH:-}" ] && return 0
_PVE_PULSE_WIZARD_SH=1

wizard() {
    clear_screen
    header "Create VM / CT wizard"
    info "This wizard builds a 'qm create' or 'pct create' command for you."
    warn "Note: this wizard needs the LOCAL backend (runs on the Proxmox node)."
    if [ "$PVE_ACTIVE_BACKEND" != "local" ]; then
        warn "Current backend is '$PVE_ACTIVE_BACKEND' - the command will only be previewed."
    fi
    printf '\n'
    local choice
    choice="$(menu "What do you want to create?" "Virtual Machine (KVM)" "Container (LXC)" "Cancel")" || return 0
    case "$choice" in
        1) wizard_vm ;;
        2) wizard_ct ;;
        *) info "Cancelled."; return 0 ;;
    esac
}

# --- shared prompts ---------------------------------------------------------
wizard_common() {
    # Sets: W_VMID W_NAME W_CORES W_MEM (MB) W_STORAGE
    W_VMID="$(ask "VMID (e.g. 200)")"
    case "$W_VMID" in ''|*[!0-9]*) warn "VMID must be numeric."; return 1 ;; esac
    W_NAME="$(ask "Name" "lab-$W_VMID")"
    W_CORES="$(ask "CPU cores" "2")"
    case "$W_CORES" in ''|*[!0-9]*|0) warn "Cores must be a positive number."; return 1 ;; esac
    W_MEM="$(ask "Memory in MB" "2048")"
    case "$W_MEM" in ''|*[!0-9]*|0) warn "Memory must be a positive number."; return 1 ;; esac
    W_STORAGE="$(ask "Storage" "local-lvm")"
    return 0
}

wizard_preview_and_run() {
    # wizard_preview_and_run <command-string> <summary...> -- show, confirm, run
    local cmd="$1"; shift
    printf '\n'
    draw_box "Command preview" "$@"
    printf '\n%s\n\n' "$cmd"
    if ! confirm "Execute this command?"; then
        info "Cancelled - nothing was created."
        return 0
    fi
    info "Executing..."
    if backend_create_guest "$cmd"; then
        ok "Guest created."
        log_action "create" "$cmd"
    else
        warn "Creation failed (code $?)."
        log_action "create-FAILED" "$cmd"
    fi
}

# --- VM wizard --------------------------------------------------------------
wizard_vm() {
    local disk iso ostype net
    wizard_common || return 0
    disk="$(ask "Disk size in GB" "20")"
    case "$disk" in ''|*[!0-9]*|0) warn "Disk must be a positive number."; return 0 ;; esac
    ostype="$(ask "OS type (l26 = Linux 6.x, win11, ...)" "l26")"
    iso="$(ask "ISO image (storage:file.iso) or leave empty" "")"
    net="$(ask "Bridge" "vmbr0")"

    local cmd="qm create $W_VMID --name '$W_NAME' --cores $W_CORES --memory $W_MEM"
    cmd="$cmd --scsi0 $W_STORAGE:$disk --ostype $ostype --net0 virtio,bridge=$net --agent 1"
    [ -n "$iso" ] && cmd="$cmd --cdrom '$iso' --boot 'order=scsi0;ide2'"

    wizard_preview_and_run "$cmd" \
        "Type:     KVM virtual machine" \
        "VMID:     $W_VMID" \
        "Name:     $W_NAME" \
        "CPU/RAM:  ${W_CORES} cores / ${W_MEM} MB" \
        "Disk:     ${disk} GB on $W_STORAGE" \
        "ISO:      ${iso:-none}" \
        "Network:  $net"
}

# --- CT wizard --------------------------------------------------------------
wizard_ct() {
    local disk template net ip
    wizard_common || return 0
    disk="$(ask "Disk size in GB" "8")"
    case "$disk" in ''|*[!0-9]*|0) warn "Disk must be a positive number."; return 0 ;; esac
    template="$(ask "Template (e.g. local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst)")"
    [ -z "$template" ] && { warn "A template is required for containers."; return 0; }
    net="$(ask "Bridge" "vmbr0")"
    ip="$(ask "IP (dhcp or e.g. 192.168.1.50/24)" "dhcp")"

    local cmd="pct create $W_VMID '$template' --hostname '$W_NAME' --cores $W_CORES"
    cmd="$cmd --memory $W_MEM --rootfs $W_STORAGE:$disk --net0 name=eth0,bridge=$net,ip=$ip"
    cmd="$cmd --unprivileged 1 --features nesting=1"

    wizard_preview_and_run "$cmd" \
        "Type:     LXC container" \
        "VMID:     $W_VMID" \
        "Hostname: $W_NAME" \
        "CPU/RAM:  ${W_CORES} cores / ${W_MEM} MB" \
        "Disk:     ${disk} GB on $W_STORAGE" \
        "Template: $template" \
        "Network:  $net ($ip)"
}
