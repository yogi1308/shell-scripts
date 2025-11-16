#!/bin/bash

# Exit on error
set -e

echo "=== Git Commit with Gemini CLI ==="
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    exit 1
fi

# Check if there are any changes to commit (including untracked files)
if git diff --quiet && git diff --cached --quiet && [ -z "$(git status --porcelain)" ]; then
    echo "No changes to commit"
    exit 0
fi

# Show what will be staged
echo "Files to be staged:"
git status --short
echo

# Stage all changes with confirmation
read -r -p "Stage all changes? [Y/n]: " stage_confirm
if [[ $stage_confirm =~ ^[Nn]$ ]]; then
    echo "Staging cancelled. You can stage files manually and run this script again."
    exit 0
fi

git add .
echo "✓ Changes staged"
echo

# Get the diff
echo "Getting diff for Gemini..."
DIFF=$(git diff --cached)

if [ -z "$DIFF" ]; then
    echo "No staged changes found"
    exit 0
fi

# Create a temporary file for the commit message
TEMP_MSG=$(mktemp)
trap "rm -f $TEMP_MSG" EXIT

# Prompt Gemini to generate commit message
echo "Requesting commit message from Gemini CLI..."
echo "Note: Gemini may ask to check the DIFF - please approve when prompted"
echo

# Ask Gemini to generate a commit message with timeout
# We pipe the diff to Gemini as standard input, which is safer.
# We also allow stderr to pass through for better debugging.
if ! echo "$DIFF" | timeout 30 gemini "Based on the git diff I'm providing, write a concise and descriptive commit message following conventional commit format. Only output the commit message, nothing else." > "$TEMP_MSG"; then
    echo "Error: Failed to get response from Gemini (timeout or error)"
    echo "Please check your internet connection and Gemini CLI setup"
    exit 1
fi

echo
echo "✓ Gemini generated the following commit message:"
echo "─────────────────────────────────────────────────"
# Check if file is empty or just whitespace
if [ -s "$TEMP_MSG" ]; then
    cat "$TEMP_MSG"
else
    echo "[Gemini returned an empty message]"
fi
echo "─────────────────────────────────────────────────"
echo

# Allow user to edit the commit message
# Use 'read -r' to handle backslashes properly
read -r -p "Do you want to (a)pprove, (e)dit, or (c)ancel? [a/e/c]: " choice

case $choice in
    e|E)
        # Open the message in the user's preferred editor
        ${EDITOR:-nano} "$TEMP_MSG"
        echo
        echo "Updated commit message:"
        echo "─────────────────────────────────────────────────"
        cat "$TEMP_MSG"
        echo "─────────────────────────────────────────────────"
        echo
        read -r -p "Proceed with this message? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Commit cancelled"
            exit 0
        fi
        ;;
    c|C)
        echo "Commit cancelled"
        exit 0
        ;;
    a|A)
        echo "Proceeding with commit..."
        ;;
    *)
        echo "Invalid choice. Commit cancelled"
        exit 1
        ;;
esac

# Read the commit message from the file
COMMIT_MSG=$(cat "$TEMP_MSG")

if [ -z "$COMMIT_MSG" ]; then
    echo "Commit message is empty. Commit cancelled."
    exit 0
fi

# Commit with the message
echo "Committing changes..."
# Use -F to read the message from the file, which handles newlines correctly
git commit -F "$TEMP_MSG"
echo "✓ Changes committed"
echo

# Push to remote
echo "Pushing to remote..."
read -r -p "Push to remote? [Y/n]: " push_confirm
if [[ $push_confirm =~ ^[Nn]$ ]]; then
    echo "Push skipped. Run 'git push' manually when ready."
    exit 0
fi

git push
echo "✓ Changes pushed successfully"
echo
echo "Done! 🚀"