# pve-pulse - lib/backend.sh
# Backend abstraction: local | api | demo
#
# Guest record format (pipe-separated, one per line):
#   type|vmid|name|status|node|cpus|ram_mb|disk_gb|ip|uptime_s
#   type   = vm | ct
#   status = running | stopped
#
# Node info format (KEY=value lines):
#   hostname, uptime_s, cpu_pct, ram_used_mb, ram_total_mb, disk_used_gb, disk_total_gb
#
# Author: Mohamed Yassi (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_BACKEND_SH:-}" ] && return 0
_PVE_PULSE_BACKEND_SH=1

# Set by pve-pulse.sh argument parsing: PVE_DEMO=1 forces the demo backend.
PVE_DEMO="${PVE_DEMO:-0}"
# Resolved backend after backend_detect: "local", "api" or "demo".
PVE_ACTIVE_BACKEND=""

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
backend_detect() {
    if [ "$PVE_DEMO" = "1" ] || [ "$PVE_BACKEND" = "demo" ]; then
        PVE_ACTIVE_BACKEND="demo"; return 0
    fi
    if [ "$PVE_BACKEND" = "local" ] || [ "$PVE_BACKEND" = "api" ]; then
        PVE_ACTIVE_BACKEND="$PVE_BACKEND"; return 0
    fi
    # auto: prefer local tools when we are ON a Proxmox node
    if command -v qm >/dev/null 2>&1 && command -v pct >/dev/null 2>&1; then
        PVE_ACTIVE_BACKEND="local"; return 0
    fi
    if [ -n "$PVE_HOST" ] && [ -n "$PVE_TOKEN" ]; then
        PVE_ACTIVE_BACKEND="api"; return 0
    fi
    PVE_ACTIVE_BACKEND="demo"; return 0
}

backend_label() {
    case "$PVE_ACTIVE_BACKEND" in
        local) printf 'local (qm/pct on this node)' ;;
        api)   printf 'api (%s)' "${PVE_HOST:-unset}" ;;
        demo)  printf 'demo (fake data)' ;;
        *)     printf 'unknown' ;;
    esac
}

# ---------------------------------------------------------------------------
# Demo backend (reads DEMO_GUESTS / DEMO_* arrays from demo/demo-data.sh)
# ---------------------------------------------------------------------------
demo_list_guests() {
    local g
    for g in "${DEMO_GUESTS[@]}"; do
        printf '%s\n' "$g"
    done
}

demo_guest_action() {  # <action> <type> <vmid>
    printf '[DEMO] simulated: %s %s %s\n' "$1" "$2" "$3"
}

demo_guest_ips() {     # <type> <vmid>
    local g ip
    for g in "${DEMO_GUESTS[@]}"; do
        IFS='|' read -r t v _ _ _ _ _ _ ip _ <<< "$g"
        if [ "$t" = "$1" ] && [ "$v" = "$2" ]; then
            printf '%s\n' "${ip:-n/a}"
            return 0
        fi
    done
    return 1
}

demo_snap_list() {     # <type> <vmid>
    local key="$1/$2" prefix="$1/$2|" s
    for s in "${DEMO_SNAPS[@]}"; do
        case "$s" in
            "$prefix"* ) printf '%s\n' "${s#$prefix}" ;;
        esac
    done
}

demo_snap_action() {   # <create|rollback|delete> <type> <vmid> <name>
    printf '[DEMO] simulated: snapshot %s on %s %s (%s)\n' "$1" "$2" "$3" "$4"
}

demo_backup_list() {
    local b
    for b in "${DEMO_BACKUPS[@]}"; do
        printf '%s\n' "$b"
    done
}

demo_backup_now() {    # <type> <vmid>
    printf '[DEMO] simulated: vzdump backup started for %s %s\n' "$1" "$2"
}

demo_node_info() {
    printf 'hostname=%s\n'        "$DEMO_NODE_HOST"
    printf 'uptime_s=%s\n'        "$DEMO_NODE_UPTIME"
    printf 'cpu_pct=%s\n'         "$DEMO_NODE_CPU"
    printf 'ram_used_mb=%s\n'     "$DEMO_NODE_RAM_USED"
    printf 'ram_total_mb=%s\n'    "$DEMO_NODE_RAM_TOTAL"
    printf 'disk_used_gb=%s\n'    "$DEMO_NODE_DISK_USED"
    printf 'disk_total_gb=%s\n'   "$DEMO_NODE_DISK_TOTAL"
}

# ---------------------------------------------------------------------------
# Local backend (runs qm/pct/pvesh on the Proxmox node itself)
# ---------------------------------------------------------------------------
local_list_guests() {
    # qm list columns: NAME VMID STATUS MEM(MB) BOOTDISK(GB) PID
    qm list 2>/dev/null | awk -v node="$PVE_NODE" 'NR>1 {
        printf "vm|%s|%s|%s|%s||||||\n", $2, $1, $3, node
    }'
    # pct list columns: VMID STATUS NAME
    pct list 2>/dev/null | awk -v node="$PVE_NODE" 'NR>1 {
        printf "ct|%s|%s|%s|%s||||||\n", $1, $3, $2, node
    }'
}

local_guest_action() {  # <start|stop|restart> <type> <vmid>
    local action="$1" type="$2" vmid="$3" cmd
    case "$type" in
        vm) cmd="qm" ;; ct) cmd="pct" ;; *) return 1 ;;
    esac
    case "$action" in
        start)   "$cmd" start "$vmid" ;;
        stop)    "$cmd" stop "$vmid" ;;
        restart) if [ "$type" = "vm" ]; then qm reboot "$vmid"; else pct restart "$vmid"; fi ;;
        *) return 1 ;;
    esac
}

local_guest_ips() {     # <type> <vmid>
    local type="$1" vmid="$2" out
    if [ "$type" = "vm" ]; then
        out="$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null)" || return 1
        printf '%s\n' "$out" | grep -oE '"ip-address"[[:space:]]*:[[:space:]]*"[^"]+"' \
            | cut -d'"' -f4 | grep -v '^127\.' | grep -v '^::1' | head -3
    else
        pct exec "$vmid" -- hostname -I 2>/dev/null | tr ' ' '\n' | head -3
    fi
}

local_snap_list() {     # <type> <vmid>
    local type="$1" vmid="$2" cmd
    case "$type" in vm) cmd="qm";; ct) cmd="pct";; *) return 1;; esac
    "$cmd" listsnapshot "$vmid" 2>/dev/null | awk 'NR>2 && $1 != "current" {print $1"|"$2"|"$3}'
}

local_snap_action() {   # <create|rollback|delete> <type> <vmid> <name>
    local action="$1" type="$2" vmid="$3" name="$4" cmd
    case "$type" in vm) cmd="qm";; ct) cmd="pct";; *) return 1;; esac
    case "$action" in
        create)   "$cmd" snapshot "$vmid" "$name" ;;
        rollback) "$cmd" rollback "$vmid" "$name" ;;
        delete)   "$cmd" delsnapshot "$vmid" "$name" ;;
        *) return 1 ;;
    esac
}

local_backup_list() {
    # vzdump archives live under the dump dir of each storage; check the
    # common spots. TODO: read the real dumpdir from storage.cfg instead
    # of guessing paths.
    local dir
    for dir in /var/lib/vz/dump /mnt/pve/*/dump; do
        [ -d "$dir" ] || continue
        find "$dir" -maxdepth 1 -type f \( -name 'vzdump-qemu-*.vma*' -o -name 'vzdump-lxc-*.tar*' \) \
            -printf '%f|%s|%T@\n' 2>/dev/null
    done | while IFS='|' read -r file size epoch; do
        printf '%s|%s MB|%s\n' "$file" "$(( size / 1024 / 1024 ))" \
            "$(date -d "@${epoch%.*}" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "${epoch%.*}" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    done
}

local_backup_now() {    # <type> <vmid>
    local type="$1" vmid="$2" mode
    [ "$type" = "vm" ] && mode="qemu" || mode="lxc"
    vzdump "$vmid" --mode snapshot --compress zstd --storage local
}

local_node_info() {
    local host up cpu ram_used ram_total disk_used disk_total
    host="$(hostname)"
    up="$(cut -d' ' -f1 /proc/uptime 2>/dev/null | cut -d. -f1)"
    # cpu usage: two quick samples of /proc/stat
    cpu="$(awk '/^cpu /{idle1=$5; total1=$2+$3+$4+$5+$6+$7+$8; 
                 cmd="sleep 0.5"; system(cmd); getline < "/proc/stat";
                 idle2=$5; total2=$2+$3+$4+$5+$6+$7+$8;
                 if (total2>total1) printf "%.0f", 100*(1-(idle2-idle1)/(total2-total1))}' /proc/stat 2>/dev/null)"
    [ -z "$cpu" ] && cpu="n/a"
    ram_total="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
    ram_used="$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print int((t-a)/1024)}' /proc/meminfo)"
    disk_total="$(df -BG / 2>/dev/null | awk 'NR==2{print $2}' | tr -d G)"
    disk_used="$(df -BG / 2>/dev/null | awk 'NR==2{print $3}' | tr -d G)"
    printf 'hostname=%s\nuptime_s=%s\ncpu_pct=%s\nram_used_mb=%s\nram_total_mb=%s\ndisk_used_gb=%s\ndisk_total_gb=%s\n' \
        "$host" "${up:-0}" "$cpu" "${ram_used:-0}" "${ram_total:-0}" "${disk_used:-0}" "${disk_total:-0}"
}

# ---------------------------------------------------------------------------
# API backend (curl + Proxmox API token)
# ---------------------------------------------------------------------------
api_curl() {
    # api_curl <method> <path> [extra curl args...] -- prints response body
    local method="$1" path="$2"; shift 2
    local tls=()
    [ "$VERIFY_TLS" = "0" ] && tls=(-k)
    curl -sS "${tls[@]}" -X "$method" \
        -H "Authorization: PVEAPIToken=$PVE_TOKEN" \
        "https://$PVE_HOST:8006/api2/json$path" "$@"
}

api_list_guests() {
    local node="${PVE_NODE}" json
    if [ -z "$node" ]; then
        node="$(api_curl GET /nodes | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["node"])' 2>/dev/null)" || return 1
        PVE_NODE="$node"
    fi
    json="$(api_curl GET "/nodes/$node/qemu")" || return 1
    printf '%s' "$json" | python3 -c "
import json,sys
for g in json.load(sys.stdin).get('data', []):
    st = 'running' if g.get('status')=='running' else 'stopped'
    print('vm|%s|%s|%s|%s|%s|%s|%s|%s|%s' % (g.get('vmid'), g.get('name','-'), st, '$node',
          g.get('cpus',''), int(g.get('maxmem',0))//1024//1024, int(g.get('maxdisk',0))//1024//1024//1024, '', g.get('uptime',0)))
" 2>/dev/null
    json="$(api_curl GET "/nodes/$node/lxc")" || return 1
    printf '%s' "$json" | python3 -c "
import json,sys
for g in json.load(sys.stdin).get('data', []):
    st = 'running' if g.get('status')=='running' else 'stopped'
    print('ct|%s|%s|%s|%s|%s|%s|%s|%s|%s' % (g.get('vmid'), g.get('name','-'), st, '$node',
          g.get('cpus',''), int(g.get('maxmem',0))//1024//1024, int(g.get('maxdisk',0))//1024//1024//1024, '', g.get('uptime',0)))
" 2>/dev/null
}

api_guest_action() {     # <start|stop|restart> <type> <vmid>
    local action="$1" type="$2" vmid="$3" kind ep
    [ "$type" = "vm" ] && kind="qemu" || kind="lxc"
    case "$action" in
        start)   ep="status/start" ;;
        stop)    ep="status/stop" ;;
        restart) ep="status/reboot" ;;
        *) return 1 ;;
    esac
    api_curl POST "/nodes/$PVE_NODE/$kind/$vmid/$ep" >/dev/null
}

api_guest_ips() {        # <type> <vmid> -- best effort via agent
    local type="$1" vmid="$2" kind
    [ "$type" = "vm" ] && kind="qemu" || kind="lxc"
    api_curl GET "/nodes/$PVE_NODE/$kind/$vmid/agent/network-get-interfaces" 2>/dev/null \
        | python3 -c "
import json,sys
try:
    for iface in json.load(sys.stdin)['data']['result']:
        for a in iface.get('ip-addresses', []):
            ip = a.get('ip-address','')
            if ip and not ip.startswith('127.') and ip != '::1':
                print(ip)
except Exception: pass
" 2>/dev/null
}

api_snap_list() {        # <type> <vmid>
    local type="$1" vmid="$2" kind
    [ "$type" = "vm" ] && kind="qemu" || kind="lxc"
    api_curl GET "/nodes/$PVE_NODE/$kind/$vmid/snapshot" 2>/dev/null \
        | python3 -c "
import json,sys
for s in json.load(sys.stdin).get('data', []):
    if s.get('name') != 'current':
        print('%s|%s|%s' % (s.get('name'), s.get('description',''), s.get('snaptime','')))
" 2>/dev/null
}

api_snap_action() {      # <create|rollback|delete> <type> <vmid> <name>
    local action="$1" type="$2" vmid="$3" name="$4" kind ep
    [ "$type" = "vm" ] && kind="qemu" || kind="lxc"
    case "$action" in
        create)   ep="snapshot" ;;
        rollback) ep="snapshot/$name/rollback" ;;
        delete)   ep="snapshot/$name" ;;
        *) return 1 ;;
    esac
    if [ "$action" = "delete" ]; then
        api_curl DELETE "/nodes/$PVE_NODE/$kind/$vmid/$ep" >/dev/null
    elif [ "$action" = "create" ]; then
        api_curl POST "/nodes/$PVE_NODE/$kind/$vmid/$ep" --data-urlencode "snapname=$name" >/dev/null
    else
        api_curl POST "/nodes/$PVE_NODE/$kind/$vmid/$ep" >/dev/null
    fi
}

api_backup_list() {
    # list vzdump archives on storage "local"
    api_curl GET "/nodes/$PVE_NODE/storage/local/content?content=backup" 2>/dev/null \
        | python3 -c "
import json,sys,datetime
for b in json.load(sys.stdin).get('data', []):
    vol = b.get('volid','').split('/')[-1]
    size = int(b.get('size',0))//1024//1024
    ctime = datetime.datetime.fromtimestamp(int(b.get('ctime',0))).strftime('%Y-%m-%d %H:%M')
    print('%s|%s MB|%s' % (vol, size, ctime))
" 2>/dev/null
}

api_backup_now() {       # <type> <vmid>
    api_curl POST "/nodes/$PVE_NODE/vzdump" \
        --data-urlencode "vmid=$2" --data-urlencode "mode=snapshot" \
        --data-urlencode "compress=zstd" --data-urlencode "storage=local" >/dev/null
}

api_node_info() {
    local json
    json="$(api_curl GET "/nodes/$PVE_NODE/status")" || return 1
    printf '%s' "$json" | python3 -c "
import json,sys
d = json.load(sys.stdin).get('data', {})
up = d.get('uptime', 0)
cpu = round(d.get('cpu', 0)*100, 1)
rt = int(d.get('memory', {}).get('total', 0))//1024//1024
ru = int(d.get('memory', {}).get('used', 0))//1024//1024
dt = int(d.get('rootfs', {}).get('total', 0))//1024//1024//1024
du = int(d.get('rootfs', {}).get('used', 0))//1024//1024//1024
print('hostname=%s\nuptime_s=%s\ncpu_pct=%s\nram_used_mb=%s\nram_total_mb=%s\ndisk_used_gb=%s\ndisk_total_gb=%s' % ('$PVE_NODE', up, cpu, ru, rt, du, dt))
" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Dispatcher: single entry points used by the rest of the app
# ---------------------------------------------------------------------------
backend_list_guests() {
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_list_guests ;;
        local) local_list_guests ;;
        api)   api_list_guests ;;
    esac
}

backend_guest_action() {  # <action> <type> <vmid>
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_guest_action "$@" ;;
        local) local_guest_action "$@" ;;
        api)   api_guest_action "$@" ;;
    esac
}

backend_guest_ips() {
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_guest_ips "$@" ;;
        local) local_guest_ips "$@" ;;
        api)   api_guest_ips "$@" ;;
    esac
}

backend_snap_list() {
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_snap_list "$@" ;;
        local) local_snap_list "$@" ;;
        api)   api_snap_list "$@" ;;
    esac
}

backend_snap_action() {  # <action> <type> <vmid> <name>
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_snap_action "$@" ;;
        local) local_snap_action "$@" ;;
        api)   api_snap_action "$@" ;;
    esac
}

backend_backup_list() {
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_backup_list ;;
        local) local_backup_list ;;
        api)   api_backup_list ;;
    esac
}

backend_backup_now() {    # <type> <vmid>
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_backup_now "$@" ;;
        local) local_backup_now "$@" ;;
        api)   api_backup_now "$@" ;;
    esac
}

backend_node_info() {
    case "$PVE_ACTIVE_BACKEND" in
        demo)  demo_node_info ;;
        local) local_node_info ;;
        api)   api_node_info ;;
    esac
}

# Guest creation (used by the wizard)
backend_create_guest() {  # <full qm|pct create command as string> -- executed or simulated
    local cmd="$1"
    if [ "$PVE_ACTIVE_BACKEND" = "demo" ]; then
        printf '[DEMO] simulated: %s\n' "$cmd"
        return 0
    fi
    if [ "$PVE_ACTIVE_BACKEND" = "api" ]; then
        warn "Guest creation via API is not implemented yet (use local backend)."
        # TODO: implement guest creation via API (POST /nodes/{node}/qemu and /lxc)
        return 2
    fi
    # local backend: run the command (built by the wizard, validated there)
    eval "$cmd"
}

# Console command suggestion per backend
backend_console_hint() {  # <type> <vmid>
    case "$PVE_ACTIVE_BACKEND" in
        demo)  printf '[DEMO] simulated console for %s %s\n' "$1" "$2" ;;
        local) [ "$1" = "vm" ] && printf 'qm terminal %s' "$2" || printf 'pct enter %s' "$2" ;;
        api)   printf 'Use the Proxmox web UI noVNC console (https://%s:8006)' "$PVE_HOST" ;;
    esac
}
