#!/usr/bin/env bash
# worktrees-setup-vscode.sh
# Optional: Generate basic VSCode workspace files (.vscode/) for a worktree
# Usage: bash worktrees-setup-vscode.sh <worktree-path>

set -euo pipefail

WORKTREE_PATH="${1:-.}"
VSCODE_DIR="$WORKTREE_PATH/.vscode"

if ! git -C "$WORKTREE_PATH" rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a valid git repo or worktree: $WORKTREE_PATH" >&2
    exit 1
fi

mkdir -p "$VSCODE_DIR"

# Detect project type
IS_NODE=0
IS_JAVA=0

[[ -f "$WORKTREE_PATH/package.json" ]] && IS_NODE=1
[[ -f "$WORKTREE_PATH/pom.xml" ]] && IS_JAVA=1

# Generate settings.json (basic workspace settings)
cat > "$VSCODE_DIR/settings.json" << 'EOF'
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": null,
  "files.exclude": {
    "**/.git": true,
    "**/node_modules": true,
    "**/target": true,
    "**/.classpath": true,
    "**/.project": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/target": true,
    "**/.git": true
  }
}
EOF

# Generate tasks.json for build/test commands
cat > "$VSCODE_DIR/tasks.json" << 'EOF'
{
  "version": "2.0.0",
  "tasks": []
}
EOF

# Parse tasks.json and add Node tasks
if [[ $IS_NODE -eq 1 ]]; then
    # Add npm test task
    jq '.tasks += [{
      "label": "npm: test",
      "type": "shell",
      "command": "npm",
      "args": ["test"],
      "problemMatcher": [],
      "group": {
        "kind": "test",
        "isDefault": true
      }
    }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
    mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"

    # Add npm start task
    jq '.tasks += [{
      "label": "npm: start",
      "type": "shell",
      "command": "npm",
      "args": ["start"],
      "problemMatcher": []
    }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
    mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"

    # Add npm build task
    if grep -q '"build"' "$WORKTREE_PATH/package.json" 2>/dev/null; then
        jq '.tasks += [{
          "label": "npm: build",
          "type": "shell",
          "command": "npm",
          "args": ["run", "build"],
          "problemMatcher": [],
          "group": {
            "kind": "build",
            "isDefault": true
          }
        }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
        mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"
    fi

    echo "✓ Generated Node tasks (npm test, npm start, npm build)"
fi

# Parse tasks.json and add Java/Maven tasks
if [[ $IS_JAVA -eq 1 ]]; then
    # Add mvn test task
    jq '.tasks += [{
      "label": "mvn: test",
      "type": "shell",
      "command": "mvn",
      "args": ["-q", "test"],
      "problemMatcher": [],
      "group": {
        "kind": "test",
        "isDefault": true
      }
    }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
    mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"

    # Add mvn compile task
    jq '.tasks += [{
      "label": "mvn: compile",
      "type": "shell",
      "command": "mvn",
      "args": ["-q", "-DskipTests", "compile"],
      "problemMatcher": [],
      "group": {
        "kind": "build",
        "isDefault": true
      }
    }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
    mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"

    # Add mvn clean install task
    jq '.tasks += [{
      "label": "mvn: clean install",
      "type": "shell",
      "command": "mvn",
      "args": ["-q", "clean", "install"],
      "problemMatcher": []
    }]' "$VSCODE_DIR/tasks.json" > "$VSCODE_DIR/tasks.json.tmp" && \
    mv "$VSCODE_DIR/tasks.json.tmp" "$VSCODE_DIR/tasks.json"

    echo "✓ Generated Java/Maven tasks (mvn test, mvn compile, mvn clean install)"
fi

# Generate extensions.json (recommended extensions)
cat > "$VSCODE_DIR/extensions.json" << 'EOF'
{
  "recommendations": []
}
EOF

# Add recommended extensions based on project type
if [[ $IS_NODE -eq 1 ]]; then
    jq '.recommendations += [
      "dbaeumer.vscode-eslint",
      "esbenp.prettier-vscode",
      "ms-vscode.js-debug"
    ]' "$VSCODE_DIR/extensions.json" > "$VSCODE_DIR/extensions.json.tmp" && \
    mv "$VSCODE_DIR/extensions.json.tmp" "$VSCODE_DIR/extensions.json"
fi

if [[ $IS_JAVA -eq 1 ]]; then
    jq '.recommendations += [
      "redhat.java",
      "microsoft.maven-for-java",
      "microsoft.vscode-maven"
    ]' "$VSCODE_DIR/extensions.json" > "$VSCODE_DIR/extensions.json.tmp" && \
    mv "$VSCODE_DIR/extensions.json.tmp" "$VSCODE_DIR/extensions.json"
fi

echo "✓ VSCode workspace setup complete: $VSCODE_DIR"
echo "   Open the worktree in VSCode: code $WORKTREE_PATH"
echo "   Run tasks: Terminal → Run Task → (select npm/mvn task)"

