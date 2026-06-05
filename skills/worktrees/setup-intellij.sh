#!/usr/bin/env bash
# worktrees-setup-intellij.sh
# Optional: Generate basic IntelliJ project files (.idea/) for a worktree
# Usage: bash worktrees-setup-intellij.sh <worktree-path>

set -euo pipefail

WORKTREE_PATH="${1:-.}"
IDEA_DIR="$WORKTREE_PATH/.idea"

if ! git -C "$WORKTREE_PATH" rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not a valid git repo or worktree: $WORKTREE_PATH" >&2
    exit 1
fi

mkdir -p "$IDEA_DIR"

# Detect project type
IS_NODE=0
IS_JAVA=0
NODE_BOOTSTRAP_STATUS="n/a"
JAVA_BOOTSTRAP_STATUS="n/a"

[[ -f "$WORKTREE_PATH/package.json" ]] && IS_NODE=1
[[ -f "$WORKTREE_PATH/pom.xml" ]] && IS_JAVA=1

# Validate/complete bootstrap before generating IDE files.
if [[ $IS_NODE -eq 1 ]]; then
    NODE_BOOTSTRAP_STATUS="ok (already present)"

    # For monorepos with npm workspaces: install root hoisted dependencies first
    if grep -q '"workspaces"' "$WORKTREE_PATH/../../../package.json" 2>/dev/null; then
        repo_root="$(git -C "$WORKTREE_PATH" rev-parse --show-toplevel)"
        if [[ ! -d "$repo_root/node_modules" ]]; then
            echo "ℹ️ monorepo detected: installing root dependencies first..."
            if ! (cd "$repo_root" && npm ci --legacy-peer-deps); then
                echo "⚠️ npm ci with --legacy-peer-deps failed at root, retrying without it..."
                (cd "$repo_root" && npm ci) || {
                    echo "❌ root npm ci failed. Cannot proceed." >&2
                    exit 1
                }
            fi
        fi
    fi

    if [[ ! -d "$WORKTREE_PATH/node_modules" ]]; then
        NODE_BOOTSTRAP_STATUS="pending"
        command -v npm >/dev/null || { echo "❌ npm is required for Node projects" >&2; exit 1; }
        echo "ℹ️ node_modules missing, running npm ci..."
        if ! (cd "$WORKTREE_PATH" && npm ci --legacy-peer-deps); then
            echo "⚠️ npm ci with --legacy-peer-deps failed, retrying without it..."
            (cd "$WORKTREE_PATH" && npm ci) || {
                echo "❌ npm ci failed. Bootstrap is incomplete; stop and fix before opening IDE." >&2
                exit 1
            }
        fi
        NODE_BOOTSTRAP_STATUS="ok (npm ci)"
    fi
    [[ -d "$WORKTREE_PATH/node_modules" ]] || { echo "❌ node_modules not found after npm ci" >&2; exit 1; }
fi

if [[ $IS_JAVA -eq 1 ]]; then
    JAVA_BOOTSTRAP_STATUS="pending"
    command -v mvn >/dev/null || { echo "❌ mvn is required for Maven projects" >&2; exit 1; }
    echo "ℹ️ running mvn -q -DskipTests compile..."
    (cd "$WORKTREE_PATH" && mvn -q -DskipTests compile) || {
        echo "❌ mvn compile failed. Bootstrap is incomplete; stop and fix before opening IDE." >&2
        exit 1
    }
    JAVA_BOOTSTRAP_STATUS="ok (mvn compile)"
fi

# Generate misc.xml (basic project config)
cat > "$IDEA_DIR/misc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectRootManager" version="2" languageLevel="JDK_11" default="true" project-jdk-name="11" project-jdk-type="JavaSDK">
    <output url="file://$PROJECT_DIR$/out" />
  </component>
</project>
EOF

# Generate modules.xml
cat > "$IDEA_DIR/modules.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectModuleManager">
    <modules>
      <module fileurl="file://$PROJECT_DIR$/.idea/modules/root.iml" filepath="$PROJECT_DIR$/.idea/modules/root.iml" />
    </modules>
  </component>
</project>
EOF

mkdir -p "$IDEA_DIR/modules"
cat > "$IDEA_DIR/modules/root.iml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<module type="GENERAL_MODULE" version="4">
  <component name="NewModuleRootManager" inherit-compiler-output="true">
    <exclude-output />
    <content url="file://$MODULE_DIR$/../.." />
    <orderEntry type="sourceFolder" forTests="false" />
  </component>
</module>
EOF

# Generate run configurations for Node
if [[ $IS_NODE -eq 1 ]]; then
    RUNCONFIG_DIR="$IDEA_DIR/runConfigurations"
    mkdir -p "$RUNCONFIG_DIR"

    cat > "$RUNCONFIG_DIR/npm_test.xml" << 'EOF'
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="npm test" type="js.build_tools.npm">
    <package-json value="$PROJECT_DIR$/package.json" />
    <command value="test" />
    <node-interpreter value="project" />
    <envs />
    <method v="2" />
  </configuration>
</component>
EOF

    cat > "$RUNCONFIG_DIR/npm_dev.xml" << 'EOF'
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="npm start" type="js.build_tools.npm">
    <package-json value="$PROJECT_DIR$/package.json" />
    <command value="start" />
    <node-interpreter value="project" />
    <envs />
    <method v="2" />
  </configuration>
</component>
EOF
    echo "✓ Generated Node run configurations"
fi

# Generate run configurations for Java/Maven
if [[ $IS_JAVA -eq 1 ]]; then
    RUNCONFIG_DIR="$IDEA_DIR/runConfigurations"
    mkdir -p "$RUNCONFIG_DIR"

    cat > "$RUNCONFIG_DIR/maven_test.xml" << 'EOF'
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="mvn test" type="MavenRunConfiguration">
    <MavenSettings>
      <option name="myGeneralSettings" />
      <option name="myRunnerSettings" />
      <option name="myRunnerParameters">
        <MavenRunnerParameters>
          <option name="profiles">
            <set />
          </option>
          <option name="goals">
            <list>
              <string>test</string>
            </list>
          </option>
          <option name="pomFileName" value="" />
          <option name="profilesMap">
            <map />
          </option>
          <option name="resolveToWorkspace" value="false" />
          <option name="workingDirPath" value="$PROJECT_DIR$" />
        </MavenRunnerParameters>
      </option>
    </MavenSettings>
    <method v="2" />
  </configuration>
</component>
EOF
    echo "✓ Generated Java/Maven run configurations"
fi

echo "✓ IntelliJ project setup complete: $IDEA_DIR"
echo "   Bootstrap (Node): $NODE_BOOTSTRAP_STATUS"
echo "   Bootstrap (Java): $JAVA_BOOTSTRAP_STATUS"
echo "   Open the worktree in IntelliJ: File → Open → $WORKTREE_PATH"

