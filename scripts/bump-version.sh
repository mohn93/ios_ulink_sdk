#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_DIR="${SCRIPT_DIR}/.."

show_usage() {
  echo "Usage: $0 <new_version> [--local]"
  echo ""
  echo "Examples:"
  echo "  $0 1.0.6          # Create tag and let CI handle version updates"
  echo "  $0 1.0.6 --local  # Update version locally (for testing)"
  echo ""
  echo "Release workflow:"
  echo "  1. Run: ./scripts/bump-version.sh 1.0.6"
  echo "  2. CI automatically updates all version strings"
  echo "  3. CI publishes to CocoaPods and creates GitHub release"
  echo ""
  echo "The --local flag updates files locally without creating a tag."
  echo "Use this for local testing only."
}

if [[ $# -lt 1 ]]; then
  show_usage
  exit 1
fi

NEW_VERSION="$1"
LOCAL_MODE="${2:-}"

# Validate version format (semver)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ ERROR: Version must be in semver format (e.g., 1.0.6)"
  exit 1
fi

cd "$SDK_DIR"

if [[ "$LOCAL_MODE" == "--local" ]]; then
  echo "Updating version to $NEW_VERSION locally..."
  echo ""

  # Update ULinkSDK.podspec
  echo "📦 Updating ULinkSDK.podspec..."
  sed -i '' "s/spec.version[[:space:]]*=[[:space:]]*[\"'][^\"']*[\"']/spec.version      = \"$NEW_VERSION\"/" ULinkSDK.podspec

  # Update ULink.swift
  echo "📦 Updating ULinkSDK/Sources/ULinkSDK/ULink.swift..."
  sed -i '' "s/private static let sdkVersion = \"[^\"]*\"/private static let sdkVersion = \"$NEW_VERSION\"/" ULinkSDK/Sources/ULinkSDK/ULink.swift

  # Update DeviceInfoHelper.swift
  echo "📦 Updating ULinkSDK/Sources/ULinkSDK/DeviceInfoHelper.swift..."
  sed -i '' "s/return \"[^\"]*\" \/\/ This should match your SDK version/return \"$NEW_VERSION\" \/\/ This should match your SDK version/" ULinkSDK/Sources/ULinkSDK/DeviceInfoHelper.swift

  # Update README.md
  echo "📦 Updating README.md..."
  sed -i '' "s/pod 'ULinkSDK', '~> [^']*'/pod 'ULinkSDK', '~> $NEW_VERSION'/" README.md
  sed -i '' "s/from: \"[^\"]*\"/from: \"$NEW_VERSION\"/" README.md
  sed -i '' "s/Select version \`[^\`]*\` or later/Select version \`$NEW_VERSION\` or later/" README.md

  echo ""
  echo "✅ Version updated to $NEW_VERSION locally"
  echo ""
  echo "Note: This is for local testing only."
  echo "For releases, just create a tag and push it."
else
  echo "Creating release tag v$NEW_VERSION..."
  echo ""

  # Check if tag already exists
  if git rev-parse "v$NEW_VERSION" >/dev/null 2>&1; then
    echo "❌ ERROR: Tag v$NEW_VERSION already exists!"
    echo "   Use a different version number."
    exit 1
  fi

  # Create and push tag
  git tag "v$NEW_VERSION"
  echo "✅ Created tag v$NEW_VERSION"

  echo ""
  read -p "Push tag to trigger release? (y/N) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin "v$NEW_VERSION"
    echo ""
    echo "✅ Tag pushed! CI will now:"
    echo "   1. Update version in all source files"
    echo "   2. Run tests"
    echo "   3. Publish to CocoaPods"
    echo "   4. Create GitHub release (enables SPM)"
    echo ""
    echo "Monitor progress at: https://github.com/mohn93/ios_ulink_sdk/actions"
  else
    echo ""
    echo "Tag created locally. Push when ready:"
    echo "  git push origin v$NEW_VERSION"
  fi
fi
