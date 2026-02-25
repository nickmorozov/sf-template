#!/usr/bin/env bash
#
# Rewrite branch-specific org aliases in protected files.
# Called by pre-commit (during local merges) and post-merge (after git pull).
#
# Usage:
#   scripts/restore-org-config.sh           # modify + stage (for pre-commit)
#   scripts/restore-org-config.sh --no-stage # modify only (for post-merge/pull)
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
