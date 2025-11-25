#!/bin/bash

echo "🔄 Starting pull for all Git repositories..."

# Find all unique .git directories, handle spaces in folder names
find . -type d -name ".git" | sort -u | while IFS= read -r git_dir; do
    repo_root=$(dirname "$git_dir")
    echo "📁 Pulling in $repo_root..."

    # Check if it's a valid Git repo
    if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Pull latest changes safely (fast-forward only)
        git -C "$repo_root" pull --ff-only
        if [ $? -eq 0 ]; then
            echo "✅ Pull successful in $repo_root"
        else
            echo "⚠️  Pull failed in $repo_root — check manually"
        fi
    else
        echo "⚠️  Not a valid Git repository: $repo_root"
    fi

    echo ""
done

echo "✅ All repositories processed."
