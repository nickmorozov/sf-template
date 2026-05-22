#!/usr/bin/env bash
#
# Run Apex tests locally with the aer runner.
#
# Modes:
#   1. Suite mode — if src/test/suites/<name>/ folders exist, run each
#      suite as a separate aer transaction with --filter-path.
#   2. Flat mode  — no suite folders, run aer once over src/ (default
#      for bumble-bee while the test layout is flat).
#
# Usage:
#   ./scripts/shell/run_aer_suites.sh                          # all
#   ./scripts/shell/run_aer_suites.sh --suite actions selectors # specific suites
#

set -euo pipefail

SUITES_DIR="src/test/suites"
SUITES=()
FAILED_SUITES=()
PASSED_SUITES=()

AER_ARGS=(test -p Admin)

# ── Args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --suite)
            shift
            while [[ $# -gt 0 && ! "$1" == --* ]]; do
                SUITES+=("$1")
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--suite name1 name2 ...]"
            exit 1
            ;;
    esac
done

# ── Suite discovery ────────────────────────────────────────────────
discover_suites() {
    [[ ! -d "$SUITES_DIR" ]] && return
    for d in "$SUITES_DIR"/*/; do
        name=$(basename "$d")
        [[ "$name" == "shared" ]] && continue
        echo "$name"
    done | sort
}

if [[ ${#SUITES[@]} -eq 0 ]]; then
    while IFS= read -r suite; do SUITES+=("$suite"); done < <(discover_suites)
fi

# ── Flat fallback: no suites → run aer once over src/ ──────────────
if [[ ${#SUITES[@]} -eq 0 ]]; then
    echo "═══════════════════════════════════════════"
    echo " No suite folders under $SUITES_DIR — running aer over src/"
    echo "═══════════════════════════════════════════"
    aer "${AER_ARGS[@]}" src
    exit $?
fi

# ── Suite mode ─────────────────────────────────────────────────────
echo "═══════════════════════════════════════════"
echo " Running ${#SUITES[@]} aer test suites"
echo "═══════════════════════════════════════════"

for SUITE in "${SUITES[@]}"; do
    SUITE_PATH="$SUITES_DIR/$SUITE"

    if [[ ! -d "$SUITE_PATH" ]]; then
        echo "  ⚠ Suite folder not found: $SUITE_PATH"
        FAILED_SUITES+=("$SUITE")
        continue
    fi

    echo "─── Suite: $SUITE ($SUITE_PATH) ───"
    if aer "${AER_ARGS[@]}" --filter-path "$SUITE_PATH" src; then
        PASSED_SUITES+=("$SUITE")
    else
        FAILED_SUITES+=("$SUITE")
        echo "  ⚠ Suite $SUITE had failures"
    fi
    echo ""
done

echo "═══════════════════════════════════════════"
echo " Results: ${#PASSED_SUITES[@]} passed, ${#FAILED_SUITES[@]} failed"
echo "═══════════════════════════════════════════"

if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
    echo " Failed suites:"
    for S in "${FAILED_SUITES[@]}"; do
        echo "   ✗ $S"
    done
    exit 1
fi

echo " All suites passed ✓"
