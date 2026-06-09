#!/usr/bin/env bash
#
# vendor-aer.sh — OPTIONAL. Vendor a prebuilt aer binary into bin/aer for
# offline/CI-cache use. Requires a valid license; the binary is NOT committed
# by the template (add bin/aer to the project's .gitignore unless you use LFS).
#
# Usage: AER_DOWNLOAD_URL=<url> ./scripts/aer/vendor-aer.sh
#
set -euo pipefail

DEST="bin/aer"
URL="${AER_DOWNLOAD_URL:-}"

if [ -z "$URL" ]; then
    echo "Set AER_DOWNLOAD_URL to a licensed aer binary URL."
    echo "aer is license-gated — you cannot use it without a license."
    exit 1
fi

mkdir -p bin
echo "Downloading aer → $DEST ..."
curl -fsSL "$URL" -o "$DEST"
chmod +x "$DEST"
echo "Vendored aer at $DEST. Ensure your AER_LICENSE_KEY is set to use it."
