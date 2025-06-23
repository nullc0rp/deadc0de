HUGO BLOG QUICK DEPLOY GUIDE
============================

NEW POST
--------
git checkout main
hugo new posts/post-name.md
nano content/posts/post-name.md
# Set draft: false when ready

EDIT POST
---------
git checkout main
nano content/posts/existing-post.md

TEST CHANGES LOCALLY
--------------------
hugo server
# Visit http://localhost:1313
# Changes reload automatically
# Ctrl+C to stop

DEPLOY TO LIVE SITE
-------------------
# 1. Save your changes
git add .
git commit -m "Your message"
git push origin main

# 2. Build site
hugo

# 3. Deploy
git stash
git checkout gh-pages
rm -rf *
git checkout main -- public/
mv public/* .
rmdir public
echo "deadc.de" > CNAME
git add .
git commit -m "Deploy: $(date)"
git push origin gh-pages
git checkout main
git stash pop

TROUBLESHOOTING
---------------
# If hugo doesn't reflect changes:
rm -rf public/ resources/ .hugo_build.lock
hugo --cleanDestinationDir

# If theme is missing (WARN messages):
git submodule update --init --recursive

QUICK DEPLOY SCRIPT
-------------------
Save as deploy.sh:
#!/bin/bash
git add . && git commit -m "$1" && git push origin main && \
hugo && git stash && git checkout gh-pages && rm -rf * && \
git checkout main -- public/ && mv public/* . && rmdir public && \
echo "deadc.de" > CNAME && git add . && \
git commit -m "Deploy: $(date)" && git push origin gh-pages && \
git checkout main && git stash pop

# Usage: ./deploy.sh "Update F710 post"

### CHEAT SHEET:


# deadc0de Blog

Security research by deadc0de. Visit at [deadc.de](https://deadc.de).

## Quick Commands

### Test Changes Locally
```
hugo server -D
# Visit http://localhost:1313
```

### Add New Blog Post
```
hugo new posts/my-post-name.md
# Edit content/posts/my-post-name.md
```

### Update Existing Post
```
# Edit content/posts/your-post-file.md
```

### Build and Deploy
```
# Build site locally (optional, for verification)
hugo --baseURL="https://deadc.de/"

# Commit changes
git add .
git commit -m "Update/Add: post description"
git push origin main
# GitHub Actions handles deployment automatically
```

### Fix Theme (if broken)
```
git submodule update --init --recursive
```
