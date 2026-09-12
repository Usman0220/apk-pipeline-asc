#!/usr/bin/env bash
# asc.sh - Droid ASC wrapper for apk-pipeline
# Droid ASC by MG193.7 (@MG1937) — https://github.com/MG1937/ASC
#
# Usage:
#   asc.sh check
#   asc.sh refs <apk> <string|type|method|field> <pattern> [--class C] [--fuzzy-class] [-o out] [--threads N] [--debug]
#   asc.sh class <apk> <class> [-o out] [--threads N] [--debug]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

asc_require() {
    if [ -z "${ASC_MAIN:-}" ]; then
        echo -e "${RED}[-]${NC} Droid ASC not found."
        echo "    Clone it to ~/ASC, or set ASC_DIR in config.env:"
        echo "    git clone https://github.com/MG1937/ASC ~/ASC"
        echo "    pip install -r ~/ASC/requirements.txt"
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}[-]${NC} python3 required but not found."
        return 1
    fi
    return 0
}

asc_check() {
    if [ -z "${ASC_MAIN:-}" ]; then
        echo -e "${YELLOW}[~]${NC} Droid ASC not found."
        echo "    Install: git clone https://github.com/MG1937/ASC ~/ASC && pip install -r ~/ASC/requirements.txt"
        return 1
    fi
    echo -e "${GREEN}[+]${NC} Droid ASC: ${ASC_MAIN}"
    python3 -c "import androguard; print('    androguard', androguard.__version__)" 2>/dev/null \
        || echo -e "${YELLOW}[~]${NC} androguard missing (needed for getclass decompile)"
    if [ -d "$(dirname "${ASC_MAIN}")/src/asc_core" ]; then
        echo -e "${GREEN}[+]${NC} asc_core modules present"
    fi
}

asc_refs() {
    asc_require || return 1

    local apk="${1:-}" ftype="${2:-}" pattern="${3:-}"
    shift 3 2>/dev/null || true

    if [ -z "$apk" ] || [ -z "$ftype" ] || [ -z "$pattern" ]; then
        echo "Usage: $(basename "$0") refs <apk> <string|type|method|field> <pattern> [--class C] [--fuzzy-class] [-o out]"
        return 1
    fi
    case "$ftype" in
        string|type|method|field) ;;
        *) echo -e "${RED}[-]${NC} Invalid ref type '$ftype' (string|type|method|field)"; return 1 ;;
    esac
    [ -f "$apk" ] || { echo -e "${RED}[-]${NC} File not found: $apk"; return 1; }

    local threads="8" debug="" out=""
    local extra_args=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --class) shift; extra_args+=("--class" "$1") ;;
            --fuzzy-class) extra_args+=("--fuzzy-class") ;;
            -o|--output) shift; out="$1" ;;
            --threads|--thread) shift; threads="$1" ;;
            --debug) debug="--debug" ;;
            *) echo -e "${YELLOW}[~]${NC} Ignoring unknown arg: $1" ;;
        esac
        shift
    done

    local asc_cmd=(python3 "$ASC_MAIN" findrefs "$apk" --threads "$threads")
    local out_arg=()
    [ -n "$debug" ] && asc_cmd+=("$debug")
    [ -n "$out" ] && out_arg=(-o "$out")

    echo -e "${CYAN}[i]${NC} ASC findrefs: $ftype '$pattern' in $(basename "$apk")..."
    "${asc_cmd[@]}" "$ftype" "$pattern" "${extra_args[@]}" "${out_arg[@]}"
}

asc_class() {
    asc_require || return 1

    local apk="${1:-}" cls="${2:-}"
    shift 2 2>/dev/null || true

    if [ -z "$apk" ] || [ -z "$cls" ]; then
        echo "Usage: $(basename "$0") class <apk> <class> [-o out]"
        return 1
    fi
    [ -f "$apk" ] || { echo -e "${RED}[-]${NC} File not found: $apk"; return 1; }

    local threads="8" debug="" out=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -o|--output) shift; out="$1" ;;
            --threads|--thread) shift; threads="$1" ;;
            --debug) debug="--debug" ;;
            *) echo -e "${YELLOW}[~]${NC} Ignoring unknown arg: $1" ;;
        esac
        shift
    done

    local asc_cmd=(python3 "$ASC_MAIN" getclass "$apk" --threads "$threads")
    local out_arg=()
    [ -n "$debug" ] && asc_cmd+=("$debug")
    [ -n "$out" ] && out_arg=(-o "$out")

    echo -e "${CYAN}[i]${NC} ASC getclass: $cls from $(basename "$apk")..."
    "${asc_cmd[@]}" "$cls" "${out_arg[@]}"
}

cmd="${1:-}"
[ -z "$cmd" ] && { echo "Usage: asc.sh {check|refs|class} ..."; exit 1; }
shift

case "$cmd" in
    check)      asc_check ;;
    refs)       asc_refs "$@" ;;
    class)      asc_class "$@" ;;
    *)          echo "Unknown command: $cmd"; echo "Usage: asc.sh {check|refs|class} ..."; exit 1 ;;
esac