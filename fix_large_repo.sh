#!/bin/bash

# --- Configuration (You might need to adjust these) ---
# *** REVIEW THIS SECTION based on your large files ***
# These patterns determine which files get converted to LFS by filter-repo.
LFS_TRACK_PATTERNS=( "*.bin" "*.dat" "*.zip" "*.gz" "*.tar" "*.iso" "*.pkg" "*.dmg" "*.exe" "*.dll" "*.pdb" "*.psd" "*.ai" "*.mov" "*.mp4" "*.mkv" "*.wav" "*.mp3" ) # Add/remove common large types

# Remote details (extracted from previous error message)
REMOTE_NAME="origin"
REMOTE_URL="https://github.com/Ali-Maq/civic-benchmark-dataset-creation.git" # Replace if this is incorrect
BRANCH_NAME="main"

# --- Safety Check ---
echo "WARNING: This script will rewrite the history of your repository."
echo "1. Make sure you have a backup."
echo "2. If this repo is shared, ensure you've coordinated with collaborators."
read -p "Type 'YES' to continue: " CONFIRMATION
if [ "$CONFIRMATION" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

# --- Step 1: Install Dependencies (Adapt if necessary) ---
echo "INFO: Ensuring git-lfs and git-filter-repo are installed..."
# Attempt using pip (common)
if ! command -v git-filter-repo &> /dev/null; then
    echo "INFO: Attempting to install git-filter-repo via pip..."
    pip install git-filter-repo || { echo "ERROR: Failed to install git-filter-repo. Please install it manually (e.g., 'pip install git-filter-repo')."; exit 1; }
fi
# Check for git-lfs (installation varies, e.g., 'brew install git-lfs' on macOS)
if ! command -v git-lfs &> /dev/null; then
    echo "ERROR: git-lfs command not found. Please install Git LFS for your system and ensure it's in your PATH."; exit 1;
fi
echo "INFO: Dependencies checked."

# --- Step 2: Initialize Git LFS ---
echo "INFO: Initializing Git LFS..."
# Use --system if you want it for all repos, or leave as is for per-repo setup
git lfs install
echo "INFO: Git LFS initialized."

# --- Step 3: Track Large File Patterns & Commit .gitattributes ---
echo "INFO: Setting up LFS tracking patterns..."
if [ ${#LFS_TRACK_PATTERNS[@]} -gt 0 ]; then
    for pattern in "${LFS_TRACK_PATTERNS[@]}"; do
        echo "INFO: Tracking pattern: $pattern"
        # Check if pattern is already tracked to avoid duplicates
        if ! grep -qF "$pattern filter=lfs diff=lfs merge=lfs -text" .gitattributes 2>/dev/null; then
             git lfs track "$pattern"
        else
             echo "INFO: Pattern '$pattern' already tracked."
        fi
    done
    # Add .gitattributes
    git add .gitattributes
    # Commit if changes were made
    if ! git diff --staged --quiet; then
        echo "INFO: Committing .gitattributes..."
        # Allow empty commit in case .gitattributes existed but was modified
        git commit --allow-empty -m "chore: Configure/update Git LFS tracking patterns"
    else
        echo "INFO: No changes to .gitattributes needed."
    fi
else
    echo "ERROR: No LFS_TRACK_PATTERNS specified. These are needed for '--to-lfs'."
    exit 1
fi


# --- Step 4: Rewrite History using git-filter-repo --to-lfs ---
echo "INFO: Rewriting history to move files matching LFS patterns..."

# Use --force because the repo state might be dirty from previous failed attempts.
# Use --to-lfs to convert files based on .gitattributes patterns.
git filter-repo --to-lfs --force

if [ $? -ne 0 ]; then
    echo "ERROR: git-filter-repo failed to rewrite history."
    # Clean up potential fast-import crash report
    rm -f .git/fast_import_crash_*
    exit 1
fi
echo "INFO: History rewriting completed."
# Clean up potential fast-import crash report on success too
rm -f .git/fast_import_crash_*


# --- Step 5: Re-add Remote Origin ---
echo "INFO: Re-adding remote '$REMOTE_NAME' with URL '$REMOTE_URL'..."
# Check if remote already exists (e.g., if filter-repo didn't remove it for some reason)
if git remote | grep -q "^${REMOTE_NAME}$"; then
  echo "INFO: Remote '$REMOTE_NAME' already exists. Setting URL..."
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
else
  echo "INFO: Adding remote '$REMOTE_NAME'..."
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to re-add remote '$REMOTE_NAME'."
    exit 1
fi
echo "INFO: Remote '$REMOTE_NAME' configured."


# --- Step 6: Force Push ---
echo "INFO: Attempting to force push to $REMOTE_NAME $BRANCH_NAME..."
git push "$REMOTE_NAME" "$BRANCH_NAME" --force

if [ $? -ne 0 ]; then
    echo "ERROR: Force push failed. The remote might still reject it, or another issue exists."
    echo "INFO: Check remote limits, network connection, or server status. Ensure LFS files were properly converted."
    exit 1
fi

echo "SUCCESS: Force push appears to have succeeded."
echo "INFO: Remember that collaborators will need to fetch and reset their local branches if they pulled the old history."

exit 0