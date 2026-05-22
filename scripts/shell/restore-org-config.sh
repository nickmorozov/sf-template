#!/usr/bin/env bash
#
# Rewrite branch-specific org aliases in protected files.
# Called by:
#   - .husky/pre-merge-commit (merge commits — modify + stage, lands in merge)
#   - .husky/post-merge       (ff pull / non-merge-commit pull — modify only)
#   - scripts/promote.sh      (between pipeline merges — modify + stage)
#
# This script only modifies (and optionally stages) files. It never commits
# anything itself — the surrounding hook context owns the commit. That keeps
# the rewrite inside the merge or commit being created, no separate "fix
# config" follow-up commit.
#
# Usage:
#   restore-org-config.sh             # modify + stage (default)
#   restore-org-config.sh --no-stage  # modify only (post-merge / ff pull)
#
# Branch → env mapping: dev, int, qa, uat → same; main → prod
# Replaces: bumblebee-{env}, bumblebee_{env}, .bb.{env}

STAGE=true
[ "${1:-}" = "--no-stage" ] && STAGE=false

BRANCH=$(git rev-parse --abbrev-ref HEAD)

case "$BRANCH" in
    dev|int|qa|uat) ENV="$BRANCH" ;;
    main)           ENV="prod" ;;
    *)              exit 0 ;;
esac

ENVS="dev|int|qa|uat|prod"
FILES=(
    .env
    .sf/config.json
    .sfdx/sfdx-config.json
    config/org-users.json
    .idea/bumble-bee.iml
    .idea/illuminatedCloud.xml
    .idea/runConfigurations/*
)

CHANGED=false
for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue

    before=$(cat "$f")

    # bumblebee-{env}  →  bumblebee-{current}   (org alias)
    perl -pi -e "s/bumblebee-(?:${ENVS})/bumblebee-${ENV}/g" "$f"

    # bumblebee_{env}  →  bumblebee_{current}    (IC symbol table path)
    perl -pi -e "s/bumblebee_(?:${ENVS})/bumblebee_${ENV}/g" "$f"

    # .bb.{env}        →  .bb.{current}          (email domain suffix)
    perl -pi -e "s/\.bb\.(?:${ENVS})/.bb.${ENV}/g" "$f"

    after=$(cat "$f")
    if [ "$before" != "$after" ]; then
        CHANGED=true
        [ "$STAGE" = true ] && git add -f "$f"
    fi
done

if [ "$CHANGED" = true ]; then
    echo "✓ Restored org config for '$BRANCH' (bumblebee-${ENV})"
fi

# Intentionally no `git commit` (or --amend) here. The hook that invoked
# this script (pre-merge-commit / scripts/promote.sh) is the one that
# creates the commit, so staged changes land in that commit naturally.
# Calling --amend from post-merge would fail with
# "fatal: You are in the middle of a merge -- cannot amend"
# whenever MERGE_HEAD is still around. Creating a standalone "Set org
# config" commit on every merge produces the noise the pre-merge-commit
# approach was added to avoid.
