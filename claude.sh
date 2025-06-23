#!/bin/bash

echo "=== Repository Information ==="
git remote -v
git branch -a

echo -e "\n=== Current Directory Structure ==="
ls -la

echo -e "\n=== Hugo Configuration ==="
if [ -f "config.toml" ]; then
    echo "--- config.toml ---"
    cat config.toml
elif [ -f "config.yaml" ]; then
    echo "--- config.yaml ---"
    cat config.yaml
elif [ -f "config.yml" ]; then
    echo "--- config.yml ---"
    cat config.yml
fi

echo -e "\n=== Theme Information ==="
if [ -d "themes" ]; then
    echo "Themes directory contents:"
    ls -la themes/
    
    if [ -d "themes/PaperMod" ]; then
        echo -e "\nPaperMod submodule status:"
        git submodule status themes/PaperMod
    fi
fi

echo -e "\n=== Git Submodule Information ==="
git submodule
