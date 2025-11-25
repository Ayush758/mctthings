#!/bin/bash

OLD_URL="http://192.168.100.72"
NEW_URL="https://gitlab.mcts.in"

echo "🔍 Updating Git remotes from $OLD_URL to $NEW_URL..."

# Process all unique .git directories
find . -type d -name ".git" | sort -u | while IFS= read -r git_dir; do
    repo_root=$(dirname "$git_dir")
    echo "📁 Repository: $repo_root"

    # Get current origin URL
    current_url=$(git -C "$repo_root" remote get-url origin 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$current_url" ]; then
        echo "⚠️  Could not get remote URL — skipping."
        continue
    fi

    # Update if it matches OLD_URL
    if [[ "$current_url" == "$OLD_URL"* ]]; then
        new_url="${current_url/$OLD_URL/$NEW_URL}"
        echo "🔁 Updating remote:"
        echo "   OLD: $current_url"
        echo "   NEW: $new_url"
        git -C "$repo_root" remote set-url origin "$new_url"
    else
        echo "✅ Already updated or different: $current_url"
    fi

    echo ""
done

echo "✅ All applicable remotes have been updated."
