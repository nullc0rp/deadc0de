# 1. Check Hugo version
hugo version

# 2. Show your config file
cat config.toml
# If using yaml or json:
cat config.yaml
cat config.json

# 3. List your directory structure
ls -la
tree -L 2 -a

# 4. Check themes directory
ls -la themes/

# 5. Check content directory
ls -la content/

# 6. Check what Hugo generates
hugo --verbose

# 7. Check the public directory after build
ls -la public/
head -20 public/index.html

# 8. Check your GitHub Pages settings
git remote -v
git branch -a

# 9. Check if you have a .github/workflows directory
ls -la .github/workflows/
