
#!/bin/bash

# GitHub organization
ORG="openziti"

# Local folder to temporarily clone repos
LOCAL_DIR=~/openziti-mirror-temp

# GitLab project URL (single project)
GITLAB_PROJECT="https://gitlab.mcts.in/mct_projects/openziti-mirror-aayush.git"

echo "Creating temporary folder $LOCAL_DIR..."
mkdir -p "$LOCAL_DIR"
cd "$LOCAL_DIR" || exit

echo "Fetching list of public repositories from GitHub..."
repos=$(curl -s "https://api.github.com/orgs/$ORG/repos?per_page=200" | jq -r '.[].clone_url')

if [ -z "$repos" ]; then
    echo "❌ ERROR: No repositories found."
    exit 1
fi

# Clone each GitHub repo into a subfolder
for repo in $repos; do
    name=$(basename "$repo" .git)
    echo "Cloning $name..."
    git clone --depth=1 "$repo" "$name"
done

# Initialize single GitLab repo if not already
echo "Initializing local repo for GitLab project..."
mkdir -p ~/openziti-mirror-final
cd ~/openziti-mirror-final || exit
git init
git remote add origin "$GITLAB_PROJECT"

# Copy all cloned repos into final folder
cp -r "$LOCAL_DIR"/* .

# Add all files to Git
git add .
git commit -m "Import all openziti repos into openziti-mirror-aayush"

# Push to GitLab
git push -u origin main

echo "🎉 All 64 repositories imported into $GITLAB_PROJECT"

# Optional: clean up
rm -rf "$LOCAL_DIR"
