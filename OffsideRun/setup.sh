#!/usr/bin/env bash
# Builds OffsideRun for the iOS Simulator and opens the project in Xcode.
#
# Usage:
#   ./setup.sh            # regenerate (if xcodegen present), build, then ask before opening Xcode
#   ./setup.sh --open     # open Xcode after the build without asking
#   ./setup.sh --no-open  # build only, never open Xcode
#   ./setup.sh --clean    # wipe Build/DerivedData before building

set -euo pipefail

cd "$(dirname "$0")"

PROJECT="OffsideRun.xcodeproj"
SCHEME="OffsideRun"
DERIVED_DATA="Build/DerivedData"
OPEN_XCODE=ask

for arg in "$@"; do
  case "$arg" in
    --open)    OPEN_XCODE=yes ;;
    --no-open) OPEN_XCODE=no ;;
    --clean)   rm -rf "$DERIVED_DATA" ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode and run: xcode-select --install" >&2
  exit 1
fi

# Regenerate the project from project.yml when xcodegen is available.
if command -v xcodegen >/dev/null 2>&1; then
  echo "==> Regenerating $PROJECT with xcodegen"
  xcodegen generate
else
  echo "==> xcodegen not installed; using existing $PROJECT (brew install xcodegen to regenerate)"
fi

echo "==> Building $SCHEME for iOS Simulator"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Build succeeded"

if [ "$OPEN_XCODE" = ask ]; then
  if [ -t 0 ]; then
    read -r -p "Open $PROJECT in Xcode? [y/N] " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) OPEN_XCODE=yes ;;
      *) OPEN_XCODE=no ;;
    esac
  else
    # Not an interactive terminal (CI, piped input): do not open Xcode.
    OPEN_XCODE=no
  fi
fi

if [ "$OPEN_XCODE" = yes ]; then
  echo "==> Opening $PROJECT in Xcode"
  open "$PROJECT"
else
  echo "==> Skipping Xcode. Open later with: open $PROJECT"
fi
