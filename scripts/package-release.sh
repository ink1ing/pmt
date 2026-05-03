#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-${PMT_VERSION:-}}"

if [ -z "$VERSION" ]; then
  echo "Usage: scripts/package-release.sh <version> [build]" >&2
  exit 1
fi

BUILD="${2:-${PMT_BUILD:-${VERSION//./}}}"
RELEASE_DIR="$ROOT_DIR/release"
ARCHIVE_DIR="$RELEASE_DIR/appcast"
APPCAST_URL_PREFIX="https://github.com/ink1ing/pmt/releases/download/v${VERSION}/"
ZIP_NAME="PMT-${VERSION}.zip"

mkdir -p "$ARCHIVE_DIR"

PMT_VERSION="$VERSION" PMT_BUILD="$BUILD" "$ROOT_DIR/scripts/build-app.sh"

rm -f "$ARCHIVE_DIR/$ZIP_NAME"
ditto -c -k --keepParent "$ROOT_DIR/dist/PMT.app" "$ARCHIVE_DIR/$ZIP_NAME"

cat > "$ARCHIVE_DIR/PMT-${VERSION}.md" <<EOF
# PMT ${VERSION}

See the GitHub release notes for this version.
EOF

"$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
  --download-url-prefix "$APPCAST_URL_PREFIX" \
  --link "https://github.com/ink1ing/pmt" \
  --embed-release-notes \
  "$ARCHIVE_DIR"

cp "$ARCHIVE_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"

echo "$ARCHIVE_DIR/$ZIP_NAME"
echo "$ROOT_DIR/appcast.xml"
