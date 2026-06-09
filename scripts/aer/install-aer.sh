#!/usr/bin/env bash
#
# install-aer.sh — install the octoberswimmer `aer` local Apex test runner.
# aer is license-gated; this installs the CLI (CI uses octoberswimmer/aer-dist@v1
# with the AER_LICENSE_KEY secret; locally we install via Homebrew or go install).
#
set -euo pipefail

if command -v aer >/dev/null 2>&1; then
    echo "aer already installed: $(command -v aer)"
    exit 0
fi

echo "Installing aer..."
if command -v brew >/dev/null 2>&1; then
    brew tap octoberswimmer/tap 2>/dev/null || true
    brew install aer || {
        echo "Homebrew install failed. See https://github.com/octoberswimmer/aer for manual install."
        exit 1
    }
elif command -v go >/dev/null 2>&1; then
    go install github.com/octoberswimmer/aer@latest
else
    echo "Need Homebrew or Go to install aer. See https://github.com/octoberswimmer/aer"
    exit 1
fi

echo "Done. aer at: $(command -v aer)"
echo "Set AER_LICENSE_KEY in your environment to activate it."
