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

PREVIEW
-------
hugo server
# Visit http://localhost:1313

DEPLOY
------
# Save changes
git add .
git commit -m "Your commit message"
git push origin main

# Build and deploy
hugo
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

DEPLOY SCRIPT (save as deploy.sh)
---------------------------------
#!/bin/bash
hugo && git stash && git checkout gh-pages && rm -rf * && \
git checkout main -- public/ && mv public/* . && rmdir public && \
echo "deadc.de" > CNAME && git add . && \
git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M')" && \
git push origin gh-pages && git checkout main && git stash pop

# Make executable: chmod +x deploy.sh
# Run: ./deploy.sh

That's it! Write on main, deploy from gh-pages.
