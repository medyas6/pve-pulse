# pve-pulse - lib/ui.sh
# TUI helpers: screen, banners, boxes, tables, menus, status badges.
# Pure bash/ANSI - no whiptail or dialog required.
#
# Author: Mohamed Yassine (github.com/medyas6) - 2026
# License: MIT

[ -n "${_PVE_PULSE_UI_SH:-}" ] && return 0
_PVE_PULSE_UI_SH=1

# ---------------------------------------------------------------------------
# Screen
# ---------------------------------------------------------------------------
clear_screen() {
    # clear only on a real terminal; stay quiet when piped
    [ -t 1 ] && command -v clear >/dev/null 2>&1 && clear
}

banner() {
    # banner -- print the pve-pulse ASCII banner
    printf '%s' "$C_CYAN"
    cat <<'EOF'
 ____   __   __  _____        ____  _   _ _     ____  _____
|  _ \  \ \ / / | ____|      |  _ \| | | | |   / ___|| ____|
| |_) |  \ V /  |  _|   _____| |_) | | | | |   \___ \|  _|
|  __/    | |   | |___ |_____|  __/| |_| | |___ ___) | |___
|_|       |_|   |_____|      |_|    \___/|_____|____/|_____|
EOF
    printf '%s' "$C_RESET"
    printf ' %sProxmox VE pulse monitor & manager%s  v%s\n\n' "$C_DIM" "$C_RESET" "$PVE_PULSE_VERSION"
}

header() {
    # header <title> -- section title with backend tag
    local title="$1"
    printf '%s== %s ==%s  %s[%s backend]%s\n\n' \
        "$C_BOLD" "$title" "$C_RESET" "$C_DIM" "$PVE_ACTIVE_BACKEND" "$C_RESET"
}

draw_box() {
    # draw_box <title> <line1> [line2 ...] -- simple bordered box
    local title="$1"; shift
    local width=56 line
    printf '+-%s-+\n' "$(printf '%*s' "$width" '' | tr ' ' '-')"
    printf '| %s%-*s%s |\n' "$C_BOLD" "$width" "$title" "$C_RESET"
    printf '+-%s-+\n' "$(printf '%*s' "$width" '' | tr ' ' '-')"
    for line in "$@"; do
        printf '| %-*s |\n' "$width" "${line:0:$width}"
    done
    printf '+-%s-+\n' "$(printf '%*s' "$width" '' | tr ' ' '-')"
}

# ---------------------------------------------------------------------------
# Status badges
# ---------------------------------------------------------------------------
badge_running()  { printf '%s[+] running%s' "$C_GREEN" "$C_RESET"; }
badge_stopped()  { printf '%s[-] stopped%s' "$C_RED"   "$C_RESET"; }

status_badge() {
    case "$1" in
        running) badge_running ;;
        *)       badge_stopped ;;
    esac
}

type_badge() {
    case "$1" in
        vm) printf '%sVM%s' "$C_BLUE" "$C_RESET" ;;
        ct) printf '%sCT%s' "$C_YELLOW" "$C_RESET" ;;
        *)  printf '%s' "$1" ;;
    esac
}

# ---------------------------------------------------------------------------
# Usage bar: usage_bar <used> <total> <width>
# ---------------------------------------------------------------------------
usage_bar() {
    local used="${1:-0}" total="${2:-1}" width="${3:-20}" pct filled empty i
    [ "$total" -le 0 ] && total=1
    pct=$(( used * 100 / total ))
    [ "$pct" -gt 100 ] && pct=100
    filled=$(( pct * width / 100 ))
    empty=$(( width - filled ))
    local bar=""
    for (( i=0; i<filled; i++ )); do bar+="#"; done
    for (( i=0; i<empty;  i++ )); do bar+="-"; done
    local col="$C_GREEN"
    [ "$pct" -ge 75 ] && col="$C_YELLOW"
    [ "$pct" -ge 90 ] && col="$C_RED"
    printf '%s[%s]%s %3d%%' "$col" "$bar" "$C_RESET" "$pct"
}

# ---------------------------------------------------------------------------
# Table printer: print_table <header...> with rows fed via stdin as "a|b|c"
# NOTE: breaks on multi-byte/emoji chars (width calc is byte-based). good
# enough for hostnames and IDs, don't feed it anything fancy.
# ---------------------------------------------------------------------------
print_table() {
    # print_table -- reads "col1|col2|..." lines on stdin, auto-widths columns
    awk -F'|' '
    { for (i=1; i<=NF; i++) if (length($i) > w[i]) w[i]=length($i); rows[NR]=$0; n=NR; cols=NF }
    END {
        for (r=1; r<=n; r++) {
            split(rows[r], f, "|")
            for (i=1; i<=cols; i++) printf "%-*s  ", w[i], f[i]
            printf "\n"
            if (r==1) { for (i=1; i<=cols; i++) { s=""; for (k=0;k<w[i];k++) s=s"-"; printf "%-*s  ", w[i], s }; printf "\n" }
        }
    }'
}

# ---------------------------------------------------------------------------
# Numbered menu: menu <prompt> <opt1> <opt2> ...
# Prints options, reads a number, echoes the chosen index (1-based) on stdout.
# Returns 1 on empty input / EOF.
# ---------------------------------------------------------------------------
menu() {
    # NOTE: everything the user *sees* goes to stderr. Only the chosen
    # number goes to stdout, so callers can do choice="$(menu ...)".
    local prompt="$1"; shift
    local opts=("$@") i choice
    printf '\n' >&2
    for (( i=0; i<${#opts[@]}; i++ )); do
        printf '  %s%2d)%s %s\n' "$C_BOLD" "$((i+1))" "$C_RESET" "${opts[$i]}" >&2
    done
    printf '\n%s > ' "$prompt" >&2
    IFS= read -r choice || return 1
    case "$choice" in
        ''|*[!0-9]*) return 1 ;;
    esac
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#opts[@]}" ]; then
        printf '%s\n' "$choice"
        return 0
    fi
    return 1
}

# ask <prompt> [default] -- free text input, echoes answer
ask() {
    local prompt="$1" default="${2:-}" ans
    if [ -n "$default" ]; then
        printf '%s [%s]: ' "$prompt" "$default" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    IFS= read -r ans || ans=""
    [ -z "$ans" ] && ans="$default"
    printf '%s\n' "$ans"
}
