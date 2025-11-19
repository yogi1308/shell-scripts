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

# Create temporary files
TEMP_MSG=$(mktemp)
GEMINI_ERROR=$(mktemp)
trap "rm -f $TEMP_MSG $GEMINI_ERROR" EXIT

# Flag to track if user entered message manually
MANUAL_ENTRY=false

# Prompt Gemini to generate commit message
echo "Requesting commit message from Gemini CLI..."
echo

# Ask Gemini to generate a commit message with timeout
# We pipe the diff to Gemini as standard input, which is safer.
if ! echo "$DIFF" | timeout 60 gemini "Based on the git diff I'm providing, write a concise and descriptive commit message following conventional commit format. Only output the commit message, nothing else." > "$TEMP_MSG" 2>"$GEMINI_ERROR"; then
    GEMINI_EXIT_CODE=$?
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Failed to get commit message from Gemini"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    
    # Analyze the error and provide specific guidance
    if [ $GEMINI_EXIT_CODE -eq 124 ]; then
        echo "⏱️  TIMEOUT: Gemini didn't respond within 30 seconds"
        echo
        echo "📝 What this means:"
        echo "   The diff you're trying to commit might be too large, or the"
        echo "   Gemini API is responding slowly right now."
        echo
        echo "💡 What you can do:"
        echo "   1. Split your changes into smaller commits:"
        echo "      → Stage specific files: git add file1.txt file2.txt"
        echo "      → Then run this script again"
        echo
        echo "   2. Check your internet speed:"
        echo "      → Run: curl -o /dev/null http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
        echo
        echo "   3. Try again in a few moments (API might be busy)"
        echo
        DIFF_SIZE=$(echo "$DIFF" | wc -l)
        DIFF_CHARS=$(echo "$DIFF" | wc -c)
        echo "   📊 Your diff stats: $DIFF_SIZE lines, $DIFF_CHARS characters"
        if [ "$DIFF_SIZE" -gt 500 ]; then
            echo "   ⚠️  Your diff is quite large (>500 lines). Consider smaller commits."
        fi
        
    elif grep -qi "api.key\|authentication\|unauthorized\|forbidden" "$GEMINI_ERROR" 2>/dev/null; then
        echo "🔑 API KEY ISSUE: Gemini can't authenticate"
        echo
        echo "📝 What this means:"
        echo "   Your Gemini API key is either missing, invalid, or expired."
        echo
        echo "💡 How to fix this:"
        echo "   1. Get a FREE API key from Google:"
        echo "      🔗 https://aistudio.google.com/app/apikey"
        echo
        echo "   2. Set up your API key:"
        echo "      → Run: gemini config set api_key YOUR_API_KEY_HERE"
        echo
        echo "   3. Verify it works:"
        echo "      → Test: gemini 'Hello, are you working?'"
        echo
        echo "   💰 Note: Gemini API has a generous free tier!"
        
    elif grep -qi "quota\|rate.limit\|too.many.requests" "$GEMINI_ERROR" 2>/dev/null; then
        echo "📊 RATE LIMIT: You've hit your API usage limit"
        echo
        echo "📝 What this means:"
        echo "   You've made too many requests to Gemini in a short time,"
        echo "   or you've exceeded your daily/monthly quota."
        echo
        echo "💡 What you can do:"
        echo "   1. Wait a few minutes and try again"
        echo "      → Free tier resets after brief cooldown"
        echo
        echo "   2. Check your quota usage:"
        echo "      🔗 https://aistudio.google.com/app/apikey"
        echo
        echo "   3. For now, write your own commit message (option below)"
        
    elif grep -qi "network\|connection\|ENOTFOUND\|ECONNREFUSED\|timeout" "$GEMINI_ERROR" 2>/dev/null; then
        echo "🌐 NETWORK ERROR: Can't reach Gemini servers"
        echo
        echo "📝 What this means:"
        echo "   Your computer can't connect to the Gemini API servers."
        echo
        echo "💡 Troubleshooting steps:"
        echo "   1. Check your internet connection:"
        echo "      → Run: ping -c 3 google.com"
        echo
        echo "   2. Check if you're behind a firewall/proxy:"
        echo "      → Corporate networks often block API calls"
        echo "      → Try: curl -I https://generativelanguage.googleapis.com"
        echo
        echo "   3. Verify DNS is working:"
        echo "      → Run: nslookup generativelanguage.googleapis.com"
        echo
        echo "   4. If on VPN, try disconnecting/reconnecting"
        
    elif ! command -v gemini &> /dev/null; then
        echo "❓ GEMINI NOT FOUND: Gemini CLI is not installed"
        echo
        echo "📝 What this means:"
        echo "   The 'gemini' command is not available on your system."
        echo
        echo "💡 How to install Gemini CLI:"
        echo "   Visit the official documentation:"
        echo "   🔗 https://github.com/google/generative-ai-cli"
        echo
        echo "   Or follow Google's installation guide:"
        echo "   🔗 https://ai.google.dev/gemini-api/docs/cli"
        
    else
        echo "❌ UNKNOWN ERROR: Something unexpected happened"
        echo
        if [ -s "$GEMINI_ERROR" ]; then
            echo "📋 Error details from Gemini:"
            echo "   ┌─────────────────────────────────────────"
            head -10 "$GEMINI_ERROR" | sed 's/^/   │ /'
            echo "   └─────────────────────────────────────────"
            echo
        fi
        echo "💡 Troubleshooting steps:"
        echo "   1. Verify Gemini CLI is working:"
        echo "      → Run: gemini --version"
        echo
        echo "   2. Test with a simple prompt:"
        echo "      → Run: gemini 'Say hello'"
        echo
        echo "   3. Check for updates:"
        echo "      → Your Gemini CLI might be outdated"
        echo
        echo "   4. Check system resources:"
        echo "      → Run: free -h (check available memory)"
        echo
        echo "   5. Review Gemini logs (if available)"
    fi
    
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # Ask if user wants to write their own commit message
    read -r -p "Would you like to write the commit message yourself? [Y/n]: " manual_confirm
    if [[ $manual_confirm =~ ^[Nn]$ ]]; then
        echo "Commit cancelled"
        exit 1
    fi
    
    # Let user write their own commit message
    echo "Enter your commit message (press Ctrl+D when done, or Ctrl+C to cancel):"
    cat > "$TEMP_MSG"
    
    # Check if user provided a message
    if [ ! -s "$TEMP_MSG" ]; then
        echo "No commit message provided. Commit cancelled."
        exit 1
    fi
    
    # Set flag to skip review step since user just wrote it
    MANUAL_ENTRY=true
fi

# Only show the review menu if Gemini generated the message
if [ "$MANUAL_ENTRY" = false ]; then
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
fi

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