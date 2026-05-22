#!/usr/bin/env bash
# ── promote.sh ─────────────────────────────────────────────────────
# Fast-track changes through the branch pipeline.
#   Forward  (default):  dev → qa → uat → main
#   Backward (--back):   main → uat → qa → dev
# Merge commits include [skip ci] so GitHub Actions won't trigger deployments.
#
# Usage:
#   npm run promote:main          # Forward, all the way to main
#   npm run promote:uat           # Forward, stop at uat
#   npm run promote:qa            # Forward, stop at qa
#   npm run promote:dev           # Merge feature branch into dev only
#
#   bash promote.sh --back            # Backmerge to dev (default)
#   bash promote.sh --back dev        # Backmerge down to dev
#   bash promote.sh --back qa         # Backmerge down to qa
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

PIPELINE=(dev qa uat main)

# ── Help ──────────────────────────────────────────────────────────
show_help() {
  cat <<'EOF'
promote.sh — Move changes through the branch pipeline

Forward (default):  dev → qa → uat → main
Backward (--back):  main → uat → qa → dev

Usage:
  npm run promote:main          Promote from current branch all the way to main
  npm run promote:uat           Promote up to uat
  npm run promote:qa            Promote up to qa
  npm run promote:dev           Merge feature branch into dev only

  bash promote.sh --back            Backmerge to dev (default)
  bash promote.sh --back qa         Backmerge down to qa
  bash promote.sh --back dev        Backmerge down to dev

Forward mode: if you're on a feature/* or hotfix/* branch, it merges
into dev first, then continues the chain to the target.

Backward mode: must be run from a pipeline branch (main/uat/qa). Walks
the pipeline in reverse, merging the higher branch into the next lower
one at each step until it reaches the target. Use this to re-sync
changes that landed via hotfix higher in the chain back down to dev.

All merge commits include [skip ci].
Requires a clean working tree (no uncommitted changes).
EOF
  exit 0
}

# ── Parse args ────────────────────────────────────────────────────
DIRECTION=forward
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
fi
if [[ "${1:-}" == "--back" ]]; then
  DIRECTION=backward
  shift
fi

# Defaults differ by direction
if [[ "$DIRECTION" == "backward" ]]; then
  TARGET="dev"
else
  TARGET="main"
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

# After each merge (and FF-pull), the post-merge hook rewrites
# branch-specific org config files via restore-org-config.sh
# --no-stage. Those modifications land in the working tree
# uncommitted. If left alone, the next `git checkout` aborts with
# "Your local changes would be overwritten". This helper commits
# them so each iteration starts with a clean tree.
commit_org_config_if_dirty() {
  local branch="$1"
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    ADMIN_OVERRIDE=1 git commit --no-verify \
      -m "Restore org config for $branch [skip ci]"
  fi
}

BRANCHES_TO_PUSH=("$ORIGINAL_BRANCH")

if [[ "$DIRECTION" == "forward" && "$on_pipeline" == false ]]; then
  echo ""
  echo "Merging $ORIGINAL_BRANCH → dev..."
  git checkout dev
  git pull --ff-only origin dev
  commit_org_config_if_dirty dev
  git merge "$ORIGINAL_BRANCH" -m "Merge $ORIGINAL_BRANCH into dev [skip ci]"
  commit_org_config_if_dirty dev
  BRANCHES_TO_PUSH+=(dev)
  START="dev"
elif [[ "$DIRECTION" == "backward" && "$on_pipeline" == false ]]; then
  echo "Error: backmerge (--back) must be run from a pipeline branch (${PIPELINE[*]})."
  echo "Currently on '$ORIGINAL_BRANCH'."
  exit 1
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

if [[ "$DIRECTION" == "forward" ]]; then
  # Forward: start_index must be < target_index, walk +1 each step
  if [[ $start_index -ge $target_index ]]; then
    if [[ "$on_pipeline" == false ]]; then
      echo ""
      echo "Merged into dev. Target ($TARGET) is at or before dev — nothing more to promote."
    else
      echo "Current branch ($START) is already at or past target ($TARGET). Nothing to do."
    fi
  else
    for ((i = start_index + 1; i <= target_index; i++)); do
      src="${PIPELINE[$((i - 1))]}"
      dst="${PIPELINE[$i]}"
      echo ""
      echo "Merging $src → $dst..."
      git checkout "$dst"
      git pull --ff-only origin "$dst"
      commit_org_config_if_dirty "$dst"
      git merge "$src" -m "Merge $src into $dst [skip ci]"
      commit_org_config_if_dirty "$dst"
      BRANCHES_TO_PUSH+=("$dst")
    done
  fi
else
  # Backward (--back): start_index must be > target_index, walk -1 each step
  if [[ $start_index -le $target_index ]]; then
    echo "Current branch ($START) is already at or below target ($TARGET). Nothing to backmerge."
  else
    for ((i = start_index - 1; i >= target_index; i--)); do
      src="${PIPELINE[$((i + 1))]}"
      dst="${PIPELINE[$i]}"
      echo ""
      echo "Backmerging $src → $dst..."
      git checkout "$dst"
      git pull --ff-only origin "$dst"
      commit_org_config_if_dirty "$dst"
      git merge "$src" -m "Merge $src into $dst [skip ci]"
      commit_org_config_if_dirty "$dst"
      BRANCHES_TO_PUSH+=("$dst")
    done
  fi
fi

# ── Push all promoted branches ────────────────────────────────────
if [[ ${#BRANCHES_TO_PUSH[@]} -gt 0 ]]; then
  echo ""
  echo "Pushing: ${BRANCHES_TO_PUSH[*]}..."
  for branch in "${BRANCHES_TO_PUSH[@]}"; do
    git push origin "$branch"
  done
  echo ""
  if [[ "$DIRECTION" == "backward" ]]; then
    echo "Done! Backmerged down to $TARGET with [skip ci] — no deployments will trigger."
  else
    echo "Done! Promoted to $TARGET with [skip ci] — no deployments will trigger."
  fi
else
  echo ""
  echo "Nothing to push."
fi

# ── Return to original branch ────────────────────────────────────
# Defensive: any post-merge mods that slipped past the per-step
# helper (e.g., the nothing-to-promote path) get committed here so
# the checkout back to a feature/* (or other) branch doesn't abort.
current=$(git rev-parse --abbrev-ref HEAD)
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  ADMIN_OVERRIDE=1 git commit --no-verify -m "Restore org config for $current [skip ci]"
  # Also push this trailing commit so remote stays consistent.
  git push origin "$current"
fi

if [[ "$on_pipeline" == false ]]; then
  git checkout dev
  git branch -d "$ORIGINAL_BRANCH"
else
  git checkout "$ORIGINAL_BRANCH"
fi
