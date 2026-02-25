# SF Project Template

```bash
# 1. Add the submodule (one-time)
git submodule add https://github.com/nickmorozov/sf-template .template

# 3. Apply the sync
node .template/sync.js

# 4. Install updated deps
npm install

# 5. Commit the submodule + synced configs
git add -A && git commit -m "chore: add project template submodule and sync configs"
```

```bash
# Pull latest template + apply in one command
npm run sync:update
```
