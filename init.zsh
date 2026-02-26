#!/bin/zsh
#
# init.zsh — Initialize this project after creating from template
#
# Usage:
#   ./init.zsh <org-url-or-name>
#   ./init.zsh https://acme--dev.sandbox.my.salesforce.com
#   ./init.zsh acme
#   ./init.zsh acme--dev
#
# Run this once after creating your repo from the template.
# It replaces placeholders, wires up the submodule, installs deps,
# and authenticates your Salesforce org.
#

set -euo pipefail

# ── Parse input ──────────────────────────────────────────────────────

if [[ -z "${1:-}" ]]; then
    echo "Usage: $0 <org-url-or-name>"
    echo ""
    echo "Examples:"
    echo "  $0 acme                                          # production org"
    echo "  $0 https://acme--dev.sandbox.my.salesforce.com   # sandbox"
    echo "  $0 acme--dev                                     # sandbox shorthand"
    echo "  $0 acme-dev-ed                                   # developer edition"
    exit 1
fi

# Extract domain from URL or use as-is, lowercase
domain=$(echo "${(L)1}" | sed -E 's|https://([^.]+)\..*|\1|')
# Project name: strip sandbox suffix (acme--dev -> acme)
name=$(echo "$domain" | sed -E 's/(.+)--.*/\1/')
# Repo name = directory name (already set by gh repo create)
repo_name=$(basename "$(pwd)")

echo ""
echo "╭─────────────────────────────────────────╮"
echo "│  Salesforce Project Init                 │"
echo "│  Repo:    ${repo_name}"
echo "│  Project: ${name}"
echo "│  Org:     ${domain}"
echo "╰─────────────────────────────────────────╯"
echo ""

# ── 1. Replace placeholders ──────────────────────────────────────────

echo "▶ Replacing placeholders..."

# Replace PROJECT_NAME in all tracked files (skip .git, node_modules, .template)
for f in $(git ls-files); do
    [[ -f "$f" ]] || continue
    [[ "$f" == "init.zsh" ]] && continue
    if grep -q 'PROJECT_NAME' "$f" 2>/dev/null; then
        sed -i '' "s/PROJECT_NAME/${name}/g" "$f"
        echo "  ~ ${f}"
    fi
done

echo "  ✓ Replaced PROJECT_NAME → ${name}"

# ── 2. Initialize submodule ──────────────────────────────────────────

echo "▶ Initializing .template submodule..."

git submodule update --init --recursive

echo "  ✓ Submodule initialized"

# ── 3. Sync template configs ─────────────────────────────────────────

echo "▶ Syncing template configs..."

node .template/sync.js --force

echo "  ✓ Configs synced"

# ── 4. Install dependencies ──────────────────────────────────────────

echo "▶ Installing dependencies..."

npm install

echo "  ✓ Dependencies installed"

# ── 5. Commit and push ───────────────────────────────────────────────

echo "▶ Committing..."

rm -f init.zsh
git add -A
git commit -m "chore: init ${name}" --no-verify
git push

echo "  ✓ Committed and pushed"

# ── 6. Org authentication ────────────────────────────────────────────

echo ""
echo "▶ Org Authentication"

url="https://"
alias="${domain//--/-}"

if [[ $domain =~ '--' ]]; then
    # Sandbox: acme--dev -> https://acme--dev.sandbox.my.salesforce.com
    url+="${domain}.sandbox"
elif [[ $domain =~ 'dev-ed' ]]; then
    # Developer Edition: acme-dev-ed -> https://acme-dev-ed.develop.my.salesforce.com
    url+="${domain}.develop"
else
    # Production: acme -> https://acme.my.salesforce.com
    url+="${domain}"
    alias="${domain}-prod"
fi

url+=".my.salesforce.com"

echo "  URL:   ${url}"
echo "  Alias: ${alias}"
echo ""
read -q "?  Authenticate now? (y/n) " && echo "" || {
    echo ""
    echo "  Skipped. Run later:"
    echo "  sf org login web --instance-url ${url} --alias ${alias} --set-default"
    echo ""
    exit 0
}

sf org login web --instance-url "${url}" --alias "${alias}" --set-default

echo ""
echo "╭─────────────────────────────────────────╮"
echo "│  ✓ Ready!                                │"
echo "│  Default org: ${alias}"
echo "│                                         │"
echo "│  Next steps:                            │"
echo "│    npm run source:pull                  │"
echo "│    npm run source:push                  │"
echo "╰─────────────────────────────────────────╯"
