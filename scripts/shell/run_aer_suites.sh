#!/usr/bin/env bash
#
# Run AER test suites as separate local transactions.
# Discovers suites from src/test/suites/{name}/ directories.
# Uses --filter-path to target each suite's folder.
#
# Usage:
#   ./scripts/shell/run_aer_suites.sh                                   # all suites
#   ./scripts/shell/run_aer_suites.sh --suite actions triggers          # specific suites (folder names)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUITES_DIR="src/test/suites"

# Namespace + skip-list are project-specific → read from config/project.config.json.
AER_NAMESPACE=""
SKIP_ARGS=()
if command -v node >/dev/null 2>&1; then
    AER_NAMESPACE="$(node "$SCRIPT_DIR/../node/config.js" aerNamespace 2>/dev/null || true)"
    while IFS= read -r _t; do
        [ -n "$_t" ] && SKIP_ARGS+=(--skip "$_t")
    done < <(node "$SCRIPT_DIR/../node/config.js" aerSkip 2>/dev/null | tr ' ' '\n')
fi
NS_ARGS=()
[ -n "$AER_NAMESPACE" ] && NS_ARGS=(--default-namespace "$AER_NAMESPACE")
FAILED_SUITES=()
PASSED_SUITES=()

# Discover suite folder names (excluding "shared")
discover_suites() {
    for d in "$SUITES_DIR"/*/; do
        name=$(basename "$d")
        [[ "$name" == "shared" ]] && continue
        echo "$name"
    done | sort
}

# Parse arguments
SUITES=()

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

# Default: all discovered suites
if [[ ${#SUITES[@]} -eq 0 ]]; then
    while IFS= read -r suite; do SUITES+=("$suite"); done < <(discover_suites)
fi

echo "═══════════════════════════════════════════"
echo " Running ${#SUITES[@]} AER test suites"
echo "═══════════════════════════════════════════"
echo ""

for SUITE in "${SUITES[@]}"; do
    SUITE_PATH="$SUITES_DIR/$SUITE"

    if [[ ! -d "$SUITE_PATH" ]]; then
        echo "  ⚠ Suite folder not found: $SUITE_PATH"
        FAILED_SUITES+=("$SUITE")
        continue
    fi

    echo "─── Suite: $SUITE ($SUITE_PATH) ───"
    if aer test "${NS_ARGS[@]}" -p Admin -p User "${SKIP_ARGS[@]}" --filter-path "$SUITE_PATH" src; then
        PASSED_SUITES+=("$SUITE")
    else
        FAILED_SUITES+=("$SUITE")
        echo "  ⚠ Suite $SUITE had failures"
    fi
    echo ""
done

# Summary
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
