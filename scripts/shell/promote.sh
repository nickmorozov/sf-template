#!/usr/bin/env bash
# ── promote.sh ─────────────────────────────────────────────────────
# Fast-track changes through the branch pipeline: dev → qa → uat → main
# Merge commits include [skip ci] so GitHub Actions won't trigger deployments.
#
# Usage:
#   npm run promote:main         # Promote all the way to main
#   npm run promote:qa           # Stop at qa
#   npm run promote:dev          # Merge feature branch into dev only
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pipeline branches come from config/project.config.json (org-neutral).
# Fallback keeps the script usable before the config is seeded.
PIPELINE_STR=""
if command -v node >/dev/null 2>&1; then
    PIPELINE_STR="$(node "$SCRIPT_DIR/../node/config.js" pipeline 2>/dev/null || true)"
fi
[ -z "$PIPELINE_STR" ] && PIPELINE_STR="dev qa uat main"
read -r -a PIPELINE <<< "$PIPELINE_STR"

# ── Help ──────────────────────────────────────────────────────────
show_help() {
    cat <<'EOF'
promote.sh — Fast-track changes through the branch pipeline

Usage:
  npm run promote:main    Promote from current branch all the way to main
  npm run promote:qa      Promote up to qa
  npm run promote:dev     Merge feature branch into dev only

Pipeline: dev → qa → main

If you're on a feature/* or hotfix/* branch, it merges into dev first,
then continues the chain to the target. Merge commits include [skip ci]
so GitHub Actions won't trigger deployments.

Requires a clean working tree (no uncommitted changes).
EOF
    exit 0
}

# ── Parse args ────────────────────────────────────────────────────
TARGET="main"
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
fi
if [[ -n "${1:-}" ]]; then
    TARGET="$1"
fi

# Validate target
valid_target=false
for branch in "${PIPELINE[@]}"; do
    if [[ "$branch" == "$TARGET" ]]; then
        valid_target=true
        break
    fi
done
if [[ "$valid_target" == false ]]; then
    echo "Error: '$TARGET' is not a valid target. Choose from: ${PIPELINE[*]}"
    exit 1
fi

# ── Preflight checks ─────────────────────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: Working tree is not clean. Commit or stash your changes first."
    exit 1
fi

ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push

# ── Determine starting point ─────────────────────────────────────
# If we're not on a pipeline branch, merge into dev first.
on_pipeline=false
for branch in "${PIPELINE[@]}"; do
    if [[ "$branch" == "$ORIGINAL_BRANCH" ]]; then
        on_pipeline=true
        break
    fi
done

echo "Fetching latest from origin..."
git fetch origin

BRANCHES_TO_PUSH=()

if [[ "$on_pipeline" == false ]]; then
    echo ""
    echo "Merging $ORIGINAL_BRANCH → dev..."
    git checkout dev
    git pull --ff-only origin dev
    git merge "$ORIGINAL_BRANCH" -m "Merge $ORIGINAL_BRANCH into dev [skip ci]"
    BRANCHES_TO_PUSH+=(dev)
    START="dev"
else
    START="$ORIGINAL_BRANCH"
fi

# ── Walk the pipeline ─────────────────────────────────────────────
# Find where to start and stop in the chain
start_index=-1
target_index=-1
for i in "${!PIPELINE[@]}"; do
    if [[ "${PIPELINE[$i]}" == "$START" ]]; then
        start_index=$i
    fi
    if [[ "${PIPELINE[$i]}" == "$TARGET" ]]; then
        target_index=$i
    fi
done

if [[ $start_index -ge $target_index ]]; then
    if [[ "$on_pipeline" == false ]]; then
        echo ""
        echo "Merged into dev. Target ($TARGET) is at or before dev — nothing more to promote."
    else
        echo "Current branch ($START) is already at or past target ($TARGET). Nothing to do."
    fi
else
    for (( i = start_index + 1; i <= target_index; i++ )); do
        src="${PIPELINE[$((i - 1))]}"
        dst="${PIPELINE[$i]}"
        echo ""
        echo "Merging $src → $dst..."
        git checkout "$dst"
        git pull --ff-only origin "$dst"
        git merge "$src" -m "Merge $src into $dst [skip ci]"
        BRANCHES_TO_PUSH+=("$dst")
    done
fi

# ── Push all promoted branches ────────────────────────────────────
if [[ ${#BRANCHES_TO_PUSH[@]} -gt 0 ]]; then
    echo ""
    echo "Pushing: ${BRANCHES_TO_PUSH[*]}..."
    for branch in "${BRANCHES_TO_PUSH[@]}"; do
        git push origin "$branch"
    done
    echo ""
    echo "Done! Promoted to $TARGET with [skip ci] — no deployments will trigger."
else
    echo ""
    echo "Nothing to push."
fi

# ── Return to original branch ────────────────────────────────────
git checkout "$ORIGINAL_BRANCH"
echo "Back on $ORIGINAL_BRANCH."
