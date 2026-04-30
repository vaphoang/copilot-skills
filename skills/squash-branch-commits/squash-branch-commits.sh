#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   squash-branch-commits.sh ["Commit message"]
#
# This script:
# - Finds current branch
# - Finds merge-base with origin/main (fallback origin/master)
# - Soft-resets to merge-base
# - Creates one commit

COMMIT_MSG="${1:-}"

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "❌ Not inside a git repository."
  exit 1
}

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Block protected branches by default
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" || "$BRANCH" == "develop" || "$BRANCH" == release/* ]]; then
  echo "❌ Refusing to squash on protected branch: $BRANCH"
  echo "   Checkout a feature branch first."
  exit 1
fi

# Refuse if working tree is dirty (uncommitted changes)
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "❌ You have uncommitted changes."
  echo "   Please commit or stash them before squashing."
  exit 1
fi

# Fetch remote refs to ensure origin/main exists locally
git fetch --prune --quiet origin || true

BASE_REF="origin/main"
if ! git show-ref --verify --quiet "refs/remotes/origin/main"; then
  BASE_REF="origin/master"
fi

if ! git show-ref --verify --quiet "refs/remotes/${BASE_REF#origin/}"; then
  # If remotes aren't available, fall back to local main/master
  if git show-ref --verify --quiet "refs/heads/main"; then
    BASE_REF="main"
  elif git show-ref --verify --quiet "refs/heads/master"; then
    BASE_REF="master"
  else
    echo "❌ Could not determine base branch (main/master)."
    echo "   Ensure you have a main or master branch, or update the script."
    exit 1
  fi
fi

MERGE_BASE="$(git merge-base "$BASE_REF" "$BRANCH")"
HEAD_SHA="$(git rev-parse HEAD)"

echo "🔎 Current branch: $BRANCH"
echo "🔎 Base ref:       $BASE_REF"
echo "🔎 Merge-base:     $MERGE_BASE"
echo "🔎 HEAD before:    $HEAD_SHA"
echo

# Determine default commit message if none provided
if [[ -z "$COMMIT_MSG" ]]; then
  # Use branch name as a friendly default
  COMMIT_MSG="Squash: ${BRANCH}"
fi

echo "⚠️ About to squash commits on '$BRANCH' into ONE commit."
echo "   Action: git reset --soft $MERGE_BASE  (keeps changes staged)"
echo "   Then:   git commit -m \"$COMMIT_MSG\""
echo

# Perform squash
git reset --soft "$MERGE_BASE"
git commit -m "$COMMIT_MSG" --no-verify

NEW_SHA="$(git rev-parse HEAD)"
echo
echo "✅ Squash complete."
echo "🔎 HEAD after:     $NEW_SHA"
echo

# Show push guidance if upstream exists
UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)"
if [[ -n "$UPSTREAM" ]]; then
  echo "📌 Upstream detected: $UPSTREAM"
  echo "➡️  To update remote branch (rewrites history), run:"
  echo "    git push --force-with-lease"
else
  echo "📌 No upstream remote set for this branch."
  echo "➡️  If you need to push for the first time:"
  echo "    git push -u origin \"$BRANCH\""
fi
