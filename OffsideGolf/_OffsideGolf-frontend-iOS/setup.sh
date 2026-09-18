#!/usr/bin/env bash
# Regenerates and builds OffsideGolf, then asks before opening Xcode.
#
# Usage:
#   ./setup.sh            # build, then prompt before opening Xcode
#   ./setup.sh --no-open  # build only

set -euo pipefail

cd "$(dirname "$0")"

PROJECT="OffsideGolf.xcodeproj"
SCHEME="OffsideGolf"
DERIVED_DATA="Build/DerivedData"
OPEN_XCODE=ask

for argument in "$@"; do
  case "$argument" in
    --no-open) OPEN_XCODE=no ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $argument" >&2
      exit 1
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is unavailable. Install Xcode and select it with xcode-select." >&2
  exit 1
fi

if command -v xcodegen >/dev/null 2>&1; then
  echo "==> Regenerating $PROJECT from project.yml"
  xcodegen generate --spec project.yml
else
  echo "==> xcodegen is unavailable; using the checked-in $PROJECT"
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
    read -r -p "Open $PROJECT in Xcode? [y/N] " response
    case "$response" in
      [yY]|[yY][eE][sS]) OPEN_XCODE=yes ;;
      *) OPEN_XCODE=no ;;
    esac
  else
    echo "==> No interactive terminal; not opening Xcode"
    OPEN_XCODE=no
  fi
fi

if [ "$OPEN_XCODE" = yes ]; then
  echo "==> Opening $PROJECT in Xcode"
  open "$PROJECT"
else
  echo "==> Skipping Xcode. Open later with: open $PROJECT"
fi
