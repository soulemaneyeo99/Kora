#!/bin/bash
set -e
source "$(dirname "$0")/env_android.sh"

echo "--- Installing missing Android SDK packages ---"
echo "ANDROID_HOME=$ANDROID_HOME"
echo "JAVA_HOME=$JAVA_HOME"

# yes-to-all to auto-accept license prompts
yes | sdkmanager --licenses > /tmp/licenses.log 2>&1 || true
echo "licenses accepted (log: /tmp/licenses.log)"

# Install platform 36 + build-tools 36 + latest platform-tools
sdkmanager --install "platforms;android-36" "build-tools;36.0.0" "platform-tools"

echo "--- Installed packages ---"
sdkmanager --list_installed | grep -E "(platform|build-tool)" | head -10
