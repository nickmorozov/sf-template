#!/bin/bash
# claude:stop — deploy and test only if src has changed since last run

set -e

HASH_FILE=".src-hash"

# Compute current hash of src directory contents
current_hash=$(find src -type f -exec md5 -q {} + 2>/dev/null | sort | md5 -q)

# Compare with stored hash
if [ -f "$HASH_FILE" ] && [ "$(cat "$HASH_FILE")" = "$current_hash" ]; then
    echo "src unchanged — skipping deploy and tests"
    exit 0
fi

echo "src changed — running deploy and tests"

npm run source:push && npm run source:compile && npm run test:apex && npm run test && npm run source:pull

# Store hash only after successful run
echo "$current_hash" > "$HASH_FILE"
