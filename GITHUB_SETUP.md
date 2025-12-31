# GitHub Repository Setup Guide

## Initial Setup

This repository is already initialized with Git. To push it to GitHub:

### Step 1: Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `Valuate` (or your preferred name)
3. Description: "Stat weight calculator addon for WoW Ascension Bronzebeard"
4. Choose Public or Private
5. **DO NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

### Step 2: Connect Local Repository to GitHub

Run these commands in the `Valuate` folder:

```bash
git remote add origin https://github.com/YOUR_USERNAME/Valuate.git
git branch -M main
git push -u origin main
```

Replace `YOUR_USERNAME` with your GitHub username.

### Step 3: Verify

Check that your files are on GitHub by visiting your repository URL.

## Regular Workflow

### Making Changes and Committing

```bash
# After making changes
git add .
git commit -m "Description of changes"
git push
```

### Creating Checkpoints

Before making experimental changes, you can create a checkpoint:

```bash
git add .
git commit -m "Checkpoint: before [description of what you're about to try]"
git push
```

If something goes wrong, you can revert:

```bash
git log --oneline  # Find the checkpoint commit hash
git reset --hard [commit-hash]  # Revert to that checkpoint
```

Or create a branch for experiments:

```bash
git checkout -b experimental-feature
# Make changes
git commit -m "Experimental changes"
# If it works, merge back: git checkout main; git merge experimental-feature
# If it doesn't work, just switch back: git checkout main
```

## Important Notes

- The `.gitignore` file excludes backup files, OS files, and IDE files
- SavedVariables (user data) are commented out in .gitignore - uncomment if you don't want to commit user settings
- Always commit before making major changes so you can revert easily

