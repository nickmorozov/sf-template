#!/usr/bin/env bash
#
# Rewrite branch-specific org aliases in protected files.
# Called by pre-commit (during local merges) and post-merge (after git pull).
#
# Usage:
#   scripts/restore-org-config.sh           # modify + stage (for pre-commit)
#   scripts/restore-org-config.sh --no-stage # modify only (for post-merge/pull)
#
# Branch → env mapping: each branch maps to itself; main → prod
# Replaces: {prefix}-{env}, {prefix}_{env}, .{prefix-initials}.{env}

STAGE=true
[ "${1:-}" = "--no-stage" ] && STAGE=false

# Derive alias prefix from project config; exit silently if unconfigured.
PREFIX=$(node scripts/node/config.js aliasPrefix)
if [ -z "$PREFIX" ]; then
    exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Build env list from pipeline config (space-separated branch names).
PIPELINE=$(node scripts/node/config.js pipeline)
ENV=""
for b in $PIPELINE; do
    if [ "$b" = "$BRANCH" ]; then
        # main branch maps to "prod" alias; all others use the branch name.
        if [ "$b" = "main" ]; then
            ENV="prod"
        else
            ENV="$b"
        fi
        break
    fi
done

# Branch not in pipeline — nothing to restore.
if [ -z "$ENV" ]; then
    exit 0
fi

# Build alternation pattern of all possible env values from pipeline.
ENVS=""
for b in $PIPELINE; do
    if [ "$b" = "main" ]; then
        e="prod"
    else
        e="$b"
    fi
    if [ -z "$ENVS" ]; then
        ENVS="$e"
    else
        ENVS="${ENVS}|${e}"
    fi
done

FILES=(
    .env
    .sf/config.json
    .sfdx/sfdx-config.json
    config/org-users.json
    .idea/illuminatedCloud.xml
    .idea/runConfigurations/*
)

# Include project iml file if it exists (named after the project).
PROJECT_NAME=$(node scripts/node/config.js projectName)
if [ -n "$PROJECT_NAME" ]; then
    FILES+=(".idea/${PROJECT_NAME}.iml")
fi

CHANGED=false
for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue

    before=$(cat "$f")

    # {prefix}-{env}  →  {prefix}-{current}   (org alias)
    perl -pi -e "s/${PREFIX}-(?:${ENVS})/${PREFIX}-${ENV}/g" "$f"

    # {prefix}_{env}  →  {prefix}_{current}    (IC symbol table path)
    perl -pi -e "s/${PREFIX}_(?:${ENVS})/${PREFIX}_${ENV}/g" "$f"

    # .{prefix}.{env}  →  .{prefix}.{current}  (email domain suffix)
    perl -pi -e "s/\.${PREFIX}\.(?:${ENVS})/.${PREFIX}.${ENV}/g" "$f"

    after=$(cat "$f")
    if [ "$before" != "$after" ]; then
        CHANGED=true
        [ "$STAGE" = true ] && git add -f "$f"
    fi
done

if [ "$CHANGED" = true ]; then
    echo "✓ Restored org config for '$BRANCH' (${PREFIX}-${ENV})"
fi
