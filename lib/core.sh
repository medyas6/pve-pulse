# pve-pulse - lib/core.sh
# Core helpers: config loading, logging, colors, small utilities.
# Sourced once by pve-pulse.sh. Guard prevents double-sourcing.
#
# Author: Mohamed Yassine (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_CORE_SH:-}" ] && return 0
_PVE_PULSE_CORE_SH=1

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
PVE_PULSE_VERSION="1.0.0"
PVE_PULSE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pve-pulse"
PVE_PULSE_CONFIG_FILE="$PVE_PULSE_CONFIG_DIR/config"
PVE_PULSE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pve-pulse"
PVE_PULSE_LOG_FILE="$PVE_PULSE_DATA_DIR/actions.log"

# ---------------------------------------------------------------------------
# Colors (disabled when NO_COLOR set, when --no-color passed, or not a tty)
# ---------------------------------------------------------------------------
PVE_PULSE_COLORS=1

color_init() {
    if [ -n "${NO_COLOR:-}" ] || [ "$PVE_PULSE_COLORS" = "0" ] || [ ! -t 1 ]; then
        C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""
        C_BLUE=""; C_CYAN=""; C_BOLD=""; C_DIM=""
    else
        C_RESET=$'\e[0m';  C_RED=$'\e[31m';  C_GREEN=$'\e[32m'
        C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
        C_BOLD=$'\e[1m';    C_DIM=$'\e[2m'
    fi
}

# ---------------------------------------------------------------------------
# Messaging helpers
# ---------------------------------------------------------------------------
die() {
    # die <message> [exit-code] -- print error and exit
    local msg="$1" code="${2:-1}"
    printf '%s%s%s\n' "$C_RED" "ERROR: $msg" "$C_RESET" >&2
    exit "$code"
}

info() {
    # info <message> -- plain informational line
    printf '%s%s%s\n' "$C_CYAN" "$1" "$C_RESET"
}

warn() {
    # warn <message> -- yellow warning to stderr
    printf '%s%s%s\n' "$C_YELLOW" "WARN: $1" "$C_RESET" >&2
}

ok() {
    # ok <message> -- green success line
    printf '%s%s%s\n' "$C_GREEN" "$1" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Logging: every real action is recorded with a timestamp.
# ---------------------------------------------------------------------------
log_init() {
    mkdir -p "$PVE_PULSE_DATA_DIR" 2>/dev/null || return 0
    [ -f "$PVE_PULSE_LOG_FILE" ] || : > "$PVE_PULSE_LOG_FILE"
}

log_action() {
    # log_action <action> <target> -- e.g. log_action "start" "VM 101 (web)"
    local action="$1" target="${2:-}" stamp
    stamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] %-10s %s\n' "$stamp" "$action" "$target" >> "$PVE_PULSE_LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Interactive helpers
# ---------------------------------------------------------------------------
confirm() {
    # confirm <prompt> -- returns 0 on yes (y/Y), 1 otherwise
    local prompt="$1" ans
    printf '%s [y/N]: ' "$prompt" >&2
    IFS= read -r ans || return 1
    case "$ans" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *)                 return 1 ;;
    esac
}

confirm_typed() {
    # confirm_typed <prompt> -- destructive actions: user must type YES
    local prompt="$1" ans
    printf '%s (type %sYES%s to confirm): ' "$prompt" "$C_BOLD" "$C_RESET" >&2
    IFS= read -r ans || return 1
    [ "$ans" = "YES" ]
}

pause() {
    # pause -- wait for Enter (skipped when stdin is not a terminal)
    if [ -t 0 ]; then
        printf '%sPress Enter to continue...%s' "$C_DIM" "$C_RESET"
        IFS= read -r _dummy < /dev/tty 2>/dev/null || IFS= read -r _dummy
        printf '\n'
    fi
}

# ---------------------------------------------------------------------------
# Config: simple KEY=value file at ~/.config/pve-pulse/config
# ---------------------------------------------------------------------------
load_config() {
    # Defaults
    PVE_BACKEND="${PVE_BACKEND:-auto}"   # auto | local | api | demo
    PVE_HOST="${PVE_HOST:-}"
    PVE_TOKEN="${PVE_TOKEN:-}"           # "USER@REALM!TOKENID=UUID" or "TOKENID=UUID"
    PVE_NODE="${PVE_NODE:-}"
    PVE_PULSE_COLORS="${PVE_PULSE_COLORS:-1}"
    VERIFY_TLS="${VERIFY_TLS:-1}"

    if [ -f "$PVE_PULSE_CONFIG_FILE" ]; then
        # shellcheck source=/dev/null - only our own KEY=value lines
        while IFS='=' read -r key value; do
            case "$key" in
                ''|\#*) continue ;;
                PVE_BACKEND|PVE_HOST|PVE_TOKEN|PVE_NODE|PVE_PULSE_COLORS|VERIFY_TLS)
                    # strip surrounding quotes if present
                    value="${value%\"}"; value="${value#\"}"
                    value="${value%\'}"; value="${value#\'}"
                    printf -v "$key" '%s' "$value"
                    ;;
            esac
        done < "$PVE_PULSE_CONFIG_FILE"
    fi
}

config_hint() {
    printf 'Config file: %s\n' "$PVE_PULSE_CONFIG_FILE"
    printf 'See config.example shipped with pve-pulse for all options.\n'
}

# ---------------------------------------------------------------------------
# Small utilities
# ---------------------------------------------------------------------------
trim() {
    # trim <string> -- strip leading/trailing whitespace
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

human_uptime() {
    # human_uptime <seconds> -- crude "2d 4h" style
    local s="${1:-0}" d h m
    d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
    if [ "$d" -gt 0 ]; then printf '%dd %dh' "$d" "$h"
    elif [ "$h" -gt 0 ]; then printf '%dh %dm' "$h" "$m"
    else printf '%dm' "$m"; fi
}
