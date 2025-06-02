#!/bin/bash

echo "🚀 ChaosChain DVN PoC - Git Setup"
echo "================================="

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install Git first."
    exit 1
fi

# Check if already in a git repo
if [ -d ".git" ]; then
    echo "⚠️  Git repository already exists!"
    read -p "Do you want to continue? This will not reinitialize. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    # Initialize git repository
    echo "📁 Initializing git repository..."
    git init
    echo "✅ Git repository initialized"
fi

# Set up default branch as main
echo "🌟 Setting default branch to 'main'..."
git branch -M main

# Add all files
echo "📦 Adding files to git..."
git add .

# Show status
echo "📋 Repository status:"
git status --short

# Check if there are any staged files
if git diff --cached --quiet; then
    echo "⚠️  No files staged for commit. Nothing to commit."
    exit 0
fi

# Commit
echo ""
read -p "📝 Enter commit message (or press Enter for default): " commit_message

if [ -z "$commit_message" ]; then
    commit_message="feat: initial ChaosChain DVN PoC implementation"
fi

echo "💾 Creating initial commit..."
git commit -m "$commit_message"

echo ""
echo "✅ Git setup complete!"
echo ""
echo "🔗 Next steps to push to GitHub:"
echo "1. Create a new repository on GitHub"
echo "2. Add remote: git remote add origin <your-repo-url>"
echo "3. Push: git push -u origin main"
echo ""
echo "🎉 Your ChaosChain DVN PoC is ready for GitHub!" 