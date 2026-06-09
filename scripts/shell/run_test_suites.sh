#!/usr/bin/env bash
#
# Run Apex test suites as separate org transactions.
# Discovers suites from src/test/suites/{name}/ directories.
# Each directory's .cls files become --class-names for that suite run.
#
# Usage:
#   ./scripts/shell/run_test_suites.sh                                   # all suites
#   ./scripts/shell/run_test_suites.sh --suite actions triggers          # specific suites (folder names)
#

set -euo pipefail

SUITES_DIR="src/test/suites"
WAIT="${npm_package_config_wait:-10}"
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

# Get test class names from .cls files in a suite folder
get_class_flags() {
    local suite_path="$1"
    for f in "$suite_path"/*.cls; do
        [[ -f "$f" ]] || continue
        echo "--class-names $(basename "$f" .cls)"
    done
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
echo " Running ${#SUITES[@]} test suites"
echo "═══════════════════════════════════════════"
echo ""

for SUITE in "${SUITES[@]}"; do
    SUITE_PATH="$SUITES_DIR/$SUITE"

    if [[ ! -d "$SUITE_PATH" ]]; then
        echo "  ⚠ Suite folder not found: $SUITE_PATH"
        FAILED_SUITES+=("$SUITE")
        continue
    fi

    CLASS_FLAGS=$(get_class_flags "$SUITE_PATH")
    if [[ -z "$CLASS_FLAGS" ]]; then
        echo "  ⚠ No test classes in $SUITE_PATH"
        continue
    fi

    echo "─── Suite: $SUITE ───"
    if eval sf apex test run $CLASS_FLAGS --result-format human --wait "$WAIT" 2>&1 | tail -5; then
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
