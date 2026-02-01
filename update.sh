#!/bin/bash

# ══════════════════════════════════════════════════════════════════════════════
#  System Update Manager — APT/NALA · SNAP · FLATPAK
#  Modern TUI with box-drawing UI
#  Version 2.0
# ══════════════════════════════════════════════════════════════════════════════

readonly VERSION="2.0"

# ── CHANGELOG ────────────────────────────────────────────────────────────────
#
#  v2.0  — 2026-02-01
#    [NEW] Modern TUI with box-drawing UI (BTOP-style)
#    [NEW] Separate panels for APT/NALA, SNAP, FLATPAK
#    [NEW] System info panel (hostname, kernel, uptime)
#    [NEW] Summary panel with total update count
#    [NEW] Auto-detection of installed package managers
#    [NEW] Fallback APT when NALA is not available
#    [NEW] Package count per source
#    [NEW] Elapsed time measurement for each upgrade
#    [NEW] Dedicated log directory /var/log/system-update/
#    [NEW] Version display in banner
#    [FIX] count_lines() double output (grep -c exit code + || echo)
#    [FIX] (( count++ )) crash with set -e when count=0
#    [FIX] flatpak/snap commands missing || true (crash with set -e)
#    [FIX] Upgrade output redirected to log (clean TUI)
#    [FIX] read -r flag added (backslash safety)
#    [OPT] set -euo pipefail (strict mode)
#    [OPT] trap ERR with $LINENO for precise error reporting
#    [OPT] Upgrade output silenced on screen, logged to file
#    [OPT] Menu shows only sources with available updates
#    [OPT] Early exit when no updates found
#
#  v1.0  — 2025-xx-xx  (original)
#    [NEW] Basic APT/NALA update & upgrade
#    [NEW] Flatpak update support
#    [NEW] Snap refresh support
#    [NEW] Interactive source selection (N/F/S/A/Q)
#    [NEW] Reboot / shutdown prompt
#    [NEW] ASCII art banner
#    [NEW] Basic logging to /var/log/
#
# ─────────────────────────────────────────────────────────────────────────────

# ------------------ Colors & Symbols ------------------
readonly RST='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly BG_BLUE='\033[44m'
readonly BG_GREEN='\033[42m'
readonly BG_RED='\033[41m'
readonly BG_YELLOW='\033[43m'
readonly BG_DARK='\033[48;5;236m'

readonly TICK="${GREEN}✔${RST}"
readonly CROSS="${RED}✖${RST}"
readonly ARROW="${CYAN}➜${RST}"
readonly DOT="${DIM}·${RST}"
readonly WARN="${YELLOW}⚠${RST}"

# Box-drawing chars
readonly TL='╭' TR='╮' BL='╰' BR='╯'
readonly HL='─' VL='│'
readonly ML='├' MR='┤'

# ------------------ CLI arguments ------------------
show_changelog() {
    echo ""
    echo -e "  ${BOLD}${WHITE}System Update Manager${RST}  ${CYAN}v${VERSION}${RST}"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────${RST}"
    echo -e "  ${BOLD}${GREEN}v2.0${RST}  ${DIM}2026-02-01${RST}"
    echo -e "  ${DIM}────────────────────────────────────────────────────${RST}"
    echo -e "  ${CYAN}[NEW]${RST} Modern TUI with box-drawing UI (BTOP-style)"
    echo -e "  ${CYAN}[NEW]${RST} Separate panels for APT/NALA, SNAP, FLATPAK"
    echo -e "  ${CYAN}[NEW]${RST} System info panel (hostname, kernel, uptime)"
    echo -e "  ${CYAN}[NEW]${RST} Summary panel with total update count"
    echo -e "  ${CYAN}[NEW]${RST} Auto-detection of installed package managers"
    echo -e "  ${CYAN}[NEW]${RST} Fallback APT when NALA is not available"
    echo -e "  ${CYAN}[NEW]${RST} Package count per source"
    echo -e "  ${CYAN}[NEW]${RST} Elapsed time measurement for each upgrade"
    echo -e "  ${CYAN}[NEW]${RST} Dedicated log directory /var/log/system-update/"
    echo -e "  ${CYAN}[NEW]${RST} Version display in banner"
    echo -e "  ${CYAN}[NEW]${RST} Changelog accessible via --changelog flag"
    echo -e "  ${RED}[FIX]${RST} count_lines() double output (grep exit code)"
    echo -e "  ${RED}[FIX]${RST} (( count++ )) crash with set -e when count=0"
    echo -e "  ${RED}[FIX]${RST} flatpak/snap missing || true (set -e crash)"
    echo -e "  ${RED}[FIX]${RST} Upgrade output redirected to log (clean TUI)"
    echo -e "  ${RED}[FIX]${RST} read -r flag added (backslash safety)"
    echo -e "  ${YELLOW}[OPT]${RST} set -euo pipefail (strict mode)"
    echo -e "  ${YELLOW}[OPT]${RST} trap ERR with \$LINENO for precise errors"
    echo -e "  ${YELLOW}[OPT]${RST} Menu shows only sources with available updates"
    echo -e "  ${YELLOW}[OPT]${RST} Early exit when no updates found"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────${RST}"
    echo -e "  ${BOLD}${WHITE}v1.0${RST}  ${DIM}2025-xx-xx  (original)${RST}"
    echo -e "  ${DIM}────────────────────────────────────────────────────${RST}"
    echo -e "  ${CYAN}[NEW]${RST} Basic APT/NALA update & upgrade"
    echo -e "  ${CYAN}[NEW]${RST} Flatpak update support"
    echo -e "  ${CYAN}[NEW]${RST} Snap refresh support"
    echo -e "  ${CYAN}[NEW]${RST} Interactive source selection (N/F/S/A/Q)"
    echo -e "  ${CYAN}[NEW]${RST} Reboot / shutdown prompt"
    echo -e "  ${CYAN}[NEW]${RST} ASCII art banner"
    echo -e "  ${CYAN}[NEW]${RST} Basic logging to /var/log/"
    echo ""
    exit 0
}

show_help() {
    echo ""
    echo -e "  ${BOLD}${WHITE}System Update Manager${RST}  ${CYAN}v${VERSION}${RST}"
    echo ""
    echo -e "  ${WHITE}Usage:${RST}  sudo ./update.sh [OPTIONS]"
    echo ""
    echo -e "  ${WHITE}Options:${RST}"
    echo -e "    ${GREEN}--changelog${RST}    Show version history"
    echo -e "    ${GREEN}--help${RST}         Show this help message"
    echo -e "    ${GREEN}--version${RST}      Show version number"
    echo ""
    exit 0
}

case "${1:-}" in
    --changelog) show_changelog ;;
    --help|-h)   show_help ;;
    --version|-v)
        echo "System Update Manager v${VERSION}"
        exit 0
        ;;
esac

# ------------------ Configuration ------------------
LOG_DIR="/var/log/system-update"
LOG_FILE="${LOG_DIR}/update_$(date '+%Y-%m-%d_%H-%M-%S').log"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
BOX_WIDTH=$(( TERM_WIDTH > 90 ? 88 : TERM_WIDTH - 2 ))
INNER_WIDTH=$(( BOX_WIDTH - 2 ))

# ------------------- Helper functions -------------------

# Log to file only (silent)
log_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null
}

# Draw a horizontal line: ╭────╮ or ├────┤ or ╰────╯
draw_line() {
    local left="$1" right="$2"
    local fill
    fill=$(printf '%*s' "$INNER_WIDTH" '' | tr ' ' "$HL")
    echo -e "${DIM}${left}${fill}${right}${RST}"
}

# Draw a box header with title and optional badge
draw_header() {
    local title="$1"
    local badge="$2"
    local badge_color="$3"
    draw_line "$TL" "$TR"
    if [[ -n "$badge" ]]; then
        local title_len=${#title}
        local badge_len=$(( ${#badge} + 2 ))
        local pad_len=$(( INNER_WIDTH - title_len - badge_len - 3 ))
        local padding
        padding=$(printf '%*s' "$pad_len" '')
        echo -e "${DIM}${VL}${RST} ${BOLD}${WHITE}${title}${RST}${padding}${badge_color} ${badge} ${RST} ${DIM}${VL}${RST}"
    else
        local title_len=${#title}
        local pad_len=$(( INNER_WIDTH - title_len - 1 ))
        local padding
        padding=$(printf '%*s' "$pad_len" '')
        echo -e "${DIM}${VL}${RST} ${BOLD}${WHITE}${title}${RST}${padding}${DIM}${VL}${RST}"
    fi
    draw_line "$ML" "$MR"
}

# Print a row inside a box
draw_row() {
    local content="$1"
    # We use printf to pad; note: ANSI codes break alignment so we
    # compute visible length separately
    local stripped
    stripped=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local vis_len=${#stripped}
    local pad_len=$(( INNER_WIDTH - vis_len - 1 ))
    if (( pad_len < 0 )); then pad_len=0; fi
    local padding
    padding=$(printf '%*s' "$pad_len" '')
    echo -e "${DIM}${VL}${RST} ${content}${padding}${DIM}${VL}${RST}"
}

# Empty row
draw_empty() {
    local padding
    padding=$(printf '%*s' "$INNER_WIDTH" '')
    echo -e "${DIM}${VL}${RST}${padding}${DIM}${VL}${RST}"
}

# Draw box footer
draw_footer() {
    draw_line "$BL" "$BR"
}

# Spinner for long operations
spinner() {
    local pid=$1
    local msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null  # hide cursor
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$i]}${RST} ${msg}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
    tput cnorm 2>/dev/null  # show cursor
    printf "\r%*s\r" "$(( ${#msg} + 6 ))" ""
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Count non-empty lines
count_lines() {
    local result
    result=$(echo "$1" | grep -c '.' 2>/dev/null) || true
    echo "${result:-0}"
}

# Format package list into aligned rows (max N shown)
format_pkg_list() {
    local data="$1"
    local max_show="${2:-15}"
    local count=0
    local total
    total=$(count_lines "$data")

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        count=$(( count + 1 ))
        if (( count <= max_show )); then
            draw_row "  ${DOT} ${DIM}${line}${RST}"
        fi
    done <<< "$data"

    if (( total > max_show )); then
        local remaining=$(( total - max_show ))
        draw_row "  ${DIM}... and ${remaining} more${RST}"
    fi
}

# ------------------- Error handling -------------------
handle_error() {
    echo ""
    draw_header "ERROR" "FAIL" "$BG_RED"
    draw_row "${CROSS} ${RED}$1${RST}"
    draw_footer
    log_file "ERROR: $1"
    exit 1
}

trap 'handle_error "An unexpected error occurred on line $LINENO"' ERR
set -euo pipefail

# ------------------ Root check ------------------
if [[ "$EUID" -ne 0 ]]; then
    echo ""
    echo -e "  ${CROSS} ${RED}This script must be run as root.${RST}"
    echo -e "  ${ARROW} Usage: ${WHITE}sudo ./update.sh${RST}"
    echo ""
    exit 1
fi

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || true

# =================== BANNER ===================
clear
echo ""
echo -e "${CYAN}${BOLD}"
cat << 'BANNER'
           ___
          |_|_|
          |_|_|              _____
          |_|_|     ____    |*_*_*|
 _______   _\__\___/ __ \____|_|_   _______
/ ____  |=|      \  <_+>  /      |=|  ____ \
~|    |\|=|======\\______//======|=|/|    |~
 |_   |    \      |      |      /    |    |
  \==-|     \     |UPDATE|     /     |----|~~/
  |   |      |    |      |    |      |____/~/
  |   |       \____\____/____/      /    / /
  |   |         {----------}       /____/ /
  |___|        /~~~~~~~~~~~~\     |_/~|_|/
   \_/        |/~~~~~||~~~~~\|     /__|\
   | |         |    ||||    |     (/|| \)
   | |        /     |  |     \       \\
   |_|        |     |  |     |
              |_____|  |_____|
              (_____)  (_____)
              |     |  |     |
              |     |  |     |
              |/~~~\|  |/~~~\|
              /|___|\  /|___|\
             <_______><_______>
BANNER
echo -e "${RST}"
echo -e "  ${DIM}System Update Manager${RST}  ${WHITE}v${VERSION}${RST}  ${DIM}APT/NALA ${DOT} SNAP ${DOT} FLATPAK${RST}"
echo ""

# =================== SYSTEM INFO ===================
HOSTNAME=$(hostname)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S')

draw_header "SYSTEM INFO" "$DATE_NOW" "$BG_BLUE"
draw_row "${ARROW} Host:   ${WHITE}${HOSTNAME}${RST}"
draw_row "${ARROW} Kernel: ${WHITE}${KERNEL}${RST}"
draw_row "${ARROW} Uptime: ${WHITE}${UPTIME}${RST}"
draw_row "${ARROW} Log:    ${DIM}${LOG_FILE}${RST}"
draw_footer
echo ""

log_file "=== System Update started at $DATE_NOW ==="
log_file "Host: $HOSTNAME | Kernel: $KERNEL"

# =================== DETECT MANAGERS ===================
HAS_NALA=false
HAS_APT=false
HAS_FLATPAK=false
HAS_SNAP=false

cmd_exists nala    && HAS_NALA=true
cmd_exists apt     && HAS_APT=true
cmd_exists flatpak && HAS_FLATPAK=true
cmd_exists snap    && HAS_SNAP=true

# We prefer nala over plain apt
USE_APT_CMD="apt"
if [[ "$HAS_NALA" == true ]]; then
    USE_APT_CMD="nala"
fi

# =================== CHECK UPDATES ===================
draw_header "SCANNING FOR UPDATES" "SCAN" "$BG_YELLOW"

# --- APT/NALA ---
APT_UPGRADES=""
APT_COUNT=0
APT_HAS_UPGRADES="no"

if [[ "$HAS_NALA" == true || "$HAS_APT" == true ]]; then
    draw_row "${ARROW} Refreshing APT package index..."
    $USE_APT_CMD update -q > /dev/null 2>&1 || true

    if [[ "$HAS_NALA" == true ]]; then
        APT_UPGRADES=$(nala list --upgradable 2>/dev/null | grep -i "upgradable" || true)
    else
        APT_UPGRADES=$(apt list --upgradable 2>/dev/null | grep -i "upgradable" || true)
    fi

    APT_COUNT=$(count_lines "$APT_UPGRADES")
    [[ "$APT_COUNT" -gt 0 ]] && APT_HAS_UPGRADES="yes"
    draw_row "  ${TICK} APT done — ${WHITE}${APT_COUNT}${RST} package(s) upgradable"
else
    draw_row "  ${DIM}APT/NALA not found — skipped${RST}"
fi

# --- FLATPAK ---
FLATPAK_UPGRADES=""
FLATPAK_COUNT=0
FLATPAK_HAS_UPGRADES="no"

if [[ "$HAS_FLATPAK" == true ]]; then
    FLATPAK_UPGRADES=$(flatpak remote-ls --updates --columns=application,version 2>/dev/null || true)
    FLATPAK_COUNT=$(count_lines "$FLATPAK_UPGRADES")
    [[ "$FLATPAK_COUNT" -gt 0 ]] && FLATPAK_HAS_UPGRADES="yes"
    draw_row "  ${TICK} Flatpak done — ${WHITE}${FLATPAK_COUNT}${RST} update(s) available"
else
    draw_row "  ${DIM}Flatpak not found — skipped${RST}"
fi

# --- SNAP ---
SNAP_UPGRADES=""
SNAP_COUNT=0
SNAP_HAS_UPGRADES="no"

if [[ "$HAS_SNAP" == true ]]; then
    SNAP_UPGRADES=$(snap refresh --list 2>/dev/null || true)
    SNAP_COUNT=$(count_lines "$SNAP_UPGRADES")
    [[ "$SNAP_COUNT" -gt 0 ]] && SNAP_HAS_UPGRADES="yes"
    draw_row "  ${TICK} Snap done — ${WHITE}${SNAP_COUNT}${RST} update(s) available"
else
    draw_row "  ${DIM}Snap not found — skipped${RST}"
fi

draw_footer
echo ""

# =================== DISPLAY UPDATE TABLES ===================

# --- APT Table ---
if [[ "$HAS_NALA" == true || "$HAS_APT" == true ]]; then
    if [[ "$APT_HAS_UPGRADES" == "yes" ]]; then
        draw_header "APT / NALA" "${APT_COUNT} pkg" "$BG_GREEN"
        format_pkg_list "$APT_UPGRADES"
    else
        draw_header "APT / NALA" "UP TO DATE" "$BG_GREEN"
        draw_row "  ${TICK} All packages are up to date"
    fi
    draw_footer
    echo ""
fi

# --- FLATPAK Table ---
if [[ "$HAS_FLATPAK" == true ]]; then
    if [[ "$FLATPAK_HAS_UPGRADES" == "yes" ]]; then
        draw_header "FLATPAK" "${FLATPAK_COUNT} app" "$BG_BLUE"
        format_pkg_list "$FLATPAK_UPGRADES"
    else
        draw_header "FLATPAK" "UP TO DATE" "$BG_BLUE"
        draw_row "  ${TICK} All Flatpak apps are up to date"
    fi
    draw_footer
    echo ""
fi

# --- SNAP Table ---
if [[ "$HAS_SNAP" == true ]]; then
    if [[ "$SNAP_HAS_UPGRADES" == "yes" ]]; then
        draw_header "SNAP" "${SNAP_COUNT} snap" "$BG_YELLOW"
        format_pkg_list "$SNAP_UPGRADES"
    else
        draw_header "SNAP" "UP TO DATE" "$BG_YELLOW"
        draw_row "  ${TICK} All Snap packages are up to date"
    fi
    draw_footer
    echo ""
fi

# =================== SUMMARY BAR ===================
TOTAL_UPDATES=$(( APT_COUNT + FLATPAK_COUNT + SNAP_COUNT ))

draw_header "SUMMARY" "${TOTAL_UPDATES} total" "$BG_DARK"
draw_row "${ARROW} APT:     ${WHITE}${APT_COUNT}${RST} package(s)"
draw_row "${ARROW} Flatpak: ${WHITE}${FLATPAK_COUNT}${RST} update(s)"
draw_row "${ARROW} Snap:    ${WHITE}${SNAP_COUNT}${RST} update(s)"
draw_empty
if [[ "$TOTAL_UPDATES" -eq 0 ]]; then
    draw_row "${TICK} ${GREEN}System is fully up to date!${RST}"
fi
draw_footer
echo ""

log_file "Updates found: APT=$APT_COUNT FLATPAK=$FLATPAK_COUNT SNAP=$SNAP_COUNT TOTAL=$TOTAL_UPDATES"

# =================== USER SELECTION ===================
if [[ "$TOTAL_UPDATES" -eq 0 ]]; then
    echo -e "  ${TICK} ${GREEN}Nothing to update. System is current.${RST}"
    echo ""
else
    draw_header "SELECT SOURCES TO UPDATE" "" ""
    draw_empty
    if [[ "$APT_HAS_UPGRADES" == "yes" ]]; then
        draw_row "  ${WHITE}[N]${RST}  APT/NALA    ${DIM}(${APT_COUNT} packages)${RST}"
    fi
    if [[ "$FLATPAK_HAS_UPGRADES" == "yes" ]]; then
        draw_row "  ${WHITE}[F]${RST}  Flatpak     ${DIM}(${FLATPAK_COUNT} updates)${RST}"
    fi
    if [[ "$SNAP_HAS_UPGRADES" == "yes" ]]; then
        draw_row "  ${WHITE}[S]${RST}  Snap        ${DIM}(${SNAP_COUNT} updates)${RST}"
    fi
    draw_empty
    draw_row "  ${WHITE}[A]${RST}  All sources"
    draw_row "  ${WHITE}[Q]${RST}  Quit"
    draw_empty
    draw_footer
    echo ""

    read -rp "  $(echo -e "${ARROW}") Your choice: " choice
    choice="${choice^^}"

    UPDATE_NALA=false
    UPDATE_FLATPAK=false
    UPDATE_SNAP=false

    if [[ "$choice" == *"Q"* ]]; then
        echo ""
        echo -e "  ${WARN} Update cancelled by user."
        log_file "Update cancelled by user."
        echo ""
        exit 0
    fi

    if [[ "$choice" == *"A"* ]]; then
        UPDATE_NALA=true
        UPDATE_FLATPAK=true
        UPDATE_SNAP=true
    else
        [[ "$choice" == *"N"* ]] && UPDATE_NALA=true
        [[ "$choice" == *"F"* ]] && UPDATE_FLATPAK=true
        [[ "$choice" == *"S"* ]] && UPDATE_SNAP=true
    fi

    echo ""

    # =================== PERFORM UPDATES ===================
    draw_header "PERFORMING UPDATES" "WORK" "$BG_YELLOW"

    # --- APT/NALA ---
    if [[ "$UPDATE_NALA" == true ]]; then
        if [[ "$APT_HAS_UPGRADES" == "yes" ]]; then
            draw_row "${ARROW} Upgrading APT/NALA packages..."
            log_file "Starting APT/NALA upgrade..."
            START_T=$SECONDS
            $USE_APT_CMD upgrade -y >> "$LOG_FILE" 2>&1 || true
            ELAPSED=$(( SECONDS - START_T ))
            draw_row "  ${TICK} APT/NALA upgrade complete ${DIM}(${ELAPSED}s)${RST}"
            log_file "APT/NALA upgrade finished in ${ELAPSED}s"
        else
            draw_row "  ${DIM}APT/NALA — no updates to install${RST}"
        fi
    fi

    # --- FLATPAK ---
    if [[ "$UPDATE_FLATPAK" == true ]]; then
        if [[ "$FLATPAK_HAS_UPGRADES" == "yes" ]]; then
            draw_row "${ARROW} Upgrading Flatpak apps..."
            log_file "Starting Flatpak upgrade..."
            START_T=$SECONDS
            flatpak update -y >> "$LOG_FILE" 2>&1 || true
            ELAPSED=$(( SECONDS - START_T ))
            draw_row "  ${TICK} Flatpak upgrade complete ${DIM}(${ELAPSED}s)${RST}"
            log_file "Flatpak upgrade finished in ${ELAPSED}s"
        else
            draw_row "  ${DIM}Flatpak — no updates to install${RST}"
        fi
    fi

    # --- SNAP ---
    if [[ "$UPDATE_SNAP" == true ]]; then
        if [[ "$SNAP_HAS_UPGRADES" == "yes" ]]; then
            draw_row "${ARROW} Refreshing Snap packages..."
            log_file "Starting Snap refresh..."
            START_T=$SECONDS
            snap refresh >> "$LOG_FILE" 2>&1 || true
            ELAPSED=$(( SECONDS - START_T ))
            draw_row "  ${TICK} Snap refresh complete ${DIM}(${ELAPSED}s)${RST}"
            log_file "Snap refresh finished in ${ELAPSED}s"
        else
            draw_row "  ${DIM}Snap — no updates to install${RST}"
        fi
    fi

    draw_empty
    draw_row "${TICK} ${GREEN}All selected updates have been applied.${RST}"
    draw_footer
    echo ""
fi

# =================== REBOOT / SHUTDOWN ===================
draw_header "POST-UPDATE" "" ""
draw_row "  ${WHITE}[Y]${RST}  Reboot now"
draw_row "  ${WHITE}[P]${RST}  Power off"
draw_row "  ${WHITE}[N]${RST}  Do nothing ${DIM}(default)${RST}"
draw_footer
echo ""

read -rp "  $(echo -e "${ARROW}") Your choice: " reboot_choice
echo ""

case "${reboot_choice^^}" in
    Y)
        log_file "User requested reboot."
        echo -e "  ${ARROW} ${WHITE}Rebooting...${RST}"
        sleep 1
        reboot
        ;;
    P)
        log_file "User requested shutdown."
        echo -e "  ${ARROW} ${WHITE}Shutting down...${RST}"
        sleep 1
        poweroff
        ;;
    *)
        log_file "Update process completed. No reboot."
        echo -e "  ${TICK} ${GREEN}Update complete. Have a great day!${RST}"
        echo ""
        ;;
esac
