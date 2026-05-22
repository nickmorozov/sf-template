#!/usr/bin/env bash
# ── promote.sh ─────────────────────────────────────────────────────
# Move changes through the branch pipeline.
#
#   Forward  (default):  feature → {dev, int} → qa → uat → main
#   Backward (--back):   main → uat → qa → {dev, int} → feature
#
# `int` is a parallel mirror of `dev` (Consumer Goods Cloud integration
# org). Every merge that touches dev is replayed against int so the two
# stay byte-for-byte in sync, but int never feeds qa/uat/main itself.
#
# Forward usage:
#   bash promote.sh                  # promote current branch up to main
#   bash promote.sh uat              # stop at uat
#   bash promote.sh qa               # stop at qa
#   bash promote.sh dev              # only merge into dev (and int)
#
# Backward usage:
#   bash promote.sh --back           # backmerge from main down to current
#   bash promote.sh --back uat       # backmerge from uat down to current
#   bash promote.sh --back qa        # backmerge from qa down to current
#
# Feature/hotfix branches:
#   - forward: feature → {dev, int}, then continue to target
#   - backward: backmerge down to {dev, int}, then merge dev → feature
#
# Merge commits include [skip ci] so GitHub Actions doesn't deploy.
# Requires a clean working tree.
# ───────────────────────────────────────────────────────────────────
set -euo pipefail

PIPELINE=(dev qa uat main)
DEV_MIRROR="int"

show_help() {
  cat <<'EOF'
promote.sh — Move changes through the branch pipeline

Forward (default):  feature → {dev, int} → qa → uat → main
Backward (--back):  main → uat → qa → {dev, int} → feature

Forward usage:
  bash promote.sh                  Promote current branch up to main
  bash promote.sh uat              Stop at uat
  bash promote.sh qa               Stop at qa
  bash promote.sh dev              Only merge into dev (and int)

Backward usage:
  bash promote.sh --back           Backmerge from main down to current
  bash promote.sh --back uat       Backmerge from uat down to current
  bash promote.sh --back qa        Backmerge from qa down to current

`int` mirrors dev: any merge into or out of dev is also performed against
int. int never feeds qa/uat/main on its own.

Feature/hotfix branches:
  forward  → feature merges into {dev, int}, then continues
  backward → backmerge reaches {dev, int}, then dev → feature

All merge commits include [skip ci] so GitHub Actions doesn't deploy.
Requires a clean working tree.
EOF
  exit 0
}

# ── Parse args ────────────────────────────────────────────────────
DIRECTION=forward
case "${1:-}" in
  --help | -h) show_help ;;
  --back)
    DIRECTION=backward
    shift
    ;;
esac

# Forward: arg = TARGET (where to stop). Default = main.
# Backward: arg = SOURCE (where to start). Default = main.
ARG="${1:-main}"

valid=false
for b in "${PIPELINE[@]}"; do
  [[ "$b" == "$ARG" ]] && valid=true
done
if [[ "$valid" == false ]]; then
  if [[ "$DIRECTION" == "backward" ]]; then
    echo "Error: '$ARG' is not a valid backmerge source. Choose from: ${PIPELINE[*]}"
  else
    echo "Error: '$ARG' is not a valid target. Choose from: ${PIPELINE[*]}"
  fi
  exit 1
fi

# ── Preflight checks ─────────────────────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash your changes first."
  exit 1
fi

ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# A branch is "on pipeline" if it's dev/qa/uat/main OR the int mirror.
on_pipeline=false
for b in "${PIPELINE[@]}" "$DEV_MIRROR"; do
  [[ "$b" == "$ORIGINAL_BRANCH" ]] && on_pipeline=true
done

# ── Return-to-original on any exit (success OR crash) ────────────
# Without this trap, a script crash mid-walk (e.g., the bash-3.2
# `declare -A` failure we hit in production) leaves the user
# stranded on whatever pipeline branch was last checked out.
return_to_original() {
  local exit_code=$?
  local current
  current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # If a merge was interrupted mid-flight, don't pile checkout on top.
  if [[ -f .git/MERGE_HEAD ]]; then
    echo ""
    echo "⚠  Merge in progress on '$current' — resolve before switching branches."
    exit "$exit_code"
  fi

  if [[ -z "$current" || "$current" == "$ORIGINAL_BRANCH" ]]; then
    exit "$exit_code"
  fi

  # Commit any leftover org-config mods so the checkout doesn't abort.
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    ADMIN_OVERRIDE=1 git commit --no-verify \
      -m "Restore org config for $current [skip ci]" 2>/dev/null || true
    git push origin "$current" 2>/dev/null || true
  fi

  if [[ "$on_pipeline" == false ]]; then
    git checkout dev 2>/dev/null || true
    # Best-effort cleanup of the local feature branch if it merged cleanly.
    git branch -d "$ORIGINAL_BRANCH" 2>/dev/null || true
  else
    git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
  fi

  exit "$exit_code"
}
trap return_to_original EXIT

echo "Fetching latest from origin..."
git fetch origin

# After each merge (and FF-pull), the post-merge hook may rewrite
# branch-specific org config files. The pre-merge-commit hook usually
# folds those into the merge commit itself, but the helper here is a
# safety net for any path the hook didn't cover.
commit_org_config_if_dirty() {
  local branch="$1"
  if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    ADMIN_OVERRIDE=1 git commit --no-verify \
      -m "Restore org config for $branch [skip ci]"
  fi
}

BRANCHES_TO_PUSH=("$ORIGINAL_BRANCH")

# do_merge SRC DST [--no-mirror]
# Performs a single merge step, mirrors against int when dev is involved.
do_merge() {
  local src="$1" dst="$2"
  local mirror_flag="${3:-}"
  echo ""
  echo "Merging $src → $dst..."
  git checkout "$dst"
  git pull --ff-only origin "$dst" 2>/dev/null || true
  commit_org_config_if_dirty "$dst"
  git merge "$src" -m "Merge $src into $dst [skip ci]"
  commit_org_config_if_dirty "$dst"
  BRANCHES_TO_PUSH+=("$dst")

  # Mirror to int when dev sits on either end of the merge.
  # Skip if either side is already int (would loop).
  if [[ "$mirror_flag" != "--no-mirror" ]] \
    && [[ "$dst" == "dev" || "$src" == "dev" ]] \
    && [[ "$dst" != "$DEV_MIRROR" && "$src" != "$DEV_MIRROR" ]]; then
    echo "  ↳ Mirror: $src → $DEV_MIRROR"
    git checkout "$DEV_MIRROR"
    git pull --ff-only origin "$DEV_MIRROR" 2>/dev/null || true
    commit_org_config_if_dirty "$DEV_MIRROR"
    git merge "$src" -m "Merge $src into $DEV_MIRROR [skip ci]"
    commit_org_config_if_dirty "$DEV_MIRROR"
    BRANCHES_TO_PUSH+=("$DEV_MIRROR")
  fi
}

# Map a pipeline branch (or the int mirror) to its index in PIPELINE.
# Treats int as dev for indexing purposes.
index_of() {
  local name="$1"
  [[ "$name" == "$DEV_MIRROR" ]] && name="dev"
  for i in "${!PIPELINE[@]}"; do
    [[ "${PIPELINE[$i]}" == "$name" ]] && {
      echo "$i"
      return
    }
  done
  echo "-1"
}

# ── Direction-specific walk ──────────────────────────────────────
if [[ "$DIRECTION" == "forward" ]]; then
  TARGET="$ARG"

  if [[ "$on_pipeline" == false ]]; then
    # feature/hotfix: merge into dev (and int via mirror)
    do_merge "$ORIGINAL_BRANCH" "dev"
    START="dev"
  else
    START="$ORIGINAL_BRANCH"
  fi

  start_index=$(index_of "$START")
  target_index=$(index_of "$TARGET")

  if [[ $start_index -ge $target_index ]]; then
    if [[ "$on_pipeline" == false ]]; then
      echo ""
      echo "Merged into dev (and $DEV_MIRROR). Target ($TARGET) is at or before dev — nothing more to promote."
    else
      echo "Current branch ($START) is already at or past target ($TARGET). Nothing to do."
    fi
  else
    for ((i = start_index + 1; i <= target_index; i++)); do
      do_merge "${PIPELINE[$((i - 1))]}" "${PIPELINE[$i]}"
    done
  fi

else
  # Backward (--back): SOURCE = top of chain, endpoint = current branch.
  SOURCE="$ARG"

  if [[ "$on_pipeline" == false ]]; then
    END="dev" # backmerge down to dev, then dev → feature at the end
  else
    END="$ORIGINAL_BRANCH"
  fi

  source_index=$(index_of "$SOURCE")
  end_index=$(index_of "$END")

  if [[ $source_index -le $end_index ]]; then
    echo "Source ($SOURCE) is at or below endpoint ($END). Nothing to backmerge."
  else
    for ((i = source_index - 1; i >= end_index; i--)); do
      do_merge "${PIPELINE[$((i + 1))]}" "${PIPELINE[$i]}"
    done

    # Feature/hotfix tail: dev → feature (no int mirror — feature isn't int).
    if [[ "$on_pipeline" == false ]]; then
      do_merge "dev" "$ORIGINAL_BRANCH" --no-mirror
    fi
  fi
fi

# ── Push all touched branches (dedup) ────────────────────────────
# Bash 3.2 (default on macOS) has no associative arrays, so dedup
# with a plain array scan instead of `declare -A`.
UNIQUE=()
for b in "${BRANCHES_TO_PUSH[@]}"; do
  seen=0
  if [[ ${#UNIQUE[@]} -gt 0 ]]; then
    for u in "${UNIQUE[@]}"; do
      if [[ "$u" == "$b" ]]; then
        seen=1
        break
      fi
    done
  fi
  [[ $seen -eq 0 ]] && UNIQUE+=("$b")
done

if [[ ${#UNIQUE[@]} -gt 0 ]]; then
  echo ""
  echo "Pushing: ${UNIQUE[*]}..."
  for b in "${UNIQUE[@]}"; do
    git push origin "$b"
  done
  echo ""
  if [[ "$DIRECTION" == "backward" ]]; then
    echo "Done! Backmerged from $SOURCE down to $END — no deployments will trigger."
  else
    echo "Done! Promoted to $TARGET — no deployments will trigger."
  fi
else
  echo ""
  echo "Nothing to push."
fi
