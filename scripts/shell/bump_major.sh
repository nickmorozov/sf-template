#!/bin/bash
# Bump major version: 1.2.4 -> 2.0.0

set -e

# Ensure clean working directory
if ! git diff --quiet sfdx-project.json package.json || ! git diff --cached --quiet sfdx-project.json package.json; then
    echo "Error: Uncommitted changes. Commit or stash first."
    exit 1
fi

NEW_VER=$(node scripts/node/bump.js major)

git add sfdx-project.json package.json
git commit -m "chore: bump version to $NEW_VER"

echo "Done! Bumped to v$NEW_VER"
