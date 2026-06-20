#!/usr/bin/env bash
# Pulls the latest release manifest and updates Formula/kt.rb.
# Usage: ./scripts/update-formula.sh [--push]

set -euo pipefail

MANIFEST_URL="${KEEPTRUSTS_MANIFEST_URL:-https://dl.keeptrusts.com/releases/latest/manifest.json}"
DOWNLOAD_BASE="${KEEPTRUSTS_DOWNLOAD_BASE:-https://dl.keeptrusts.com}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FORMULA="${TAP_ROOT}/Formula/kt.rb"
DO_PUSH=false

for arg in "$@"; do
    case "$arg" in
        --push) DO_PUSH=true ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required" >&2; exit 1
fi

echo "Fetching manifest from ${MANIFEST_URL}"
manifest="$(curl -fsSL "$MANIFEST_URL")"

extract() {
    local key="$1"
    printf '%s' "$manifest" | python3 -c "import sys,json; print(json.load(sys.stdin)${key})"
}

sha_for() {
    local filename="$1"
    printf '%s' "$manifest" | python3 -c "
import sys, json
for a in json.load(sys.stdin)['artifacts']:
    if a['filename'] == '$filename':
        print(a['sha256']); break
"
}

VERSION="$(extract "['version']")"
SHA_MACOS="$(sha_for "kt-macos-universal.tar.gz")"
SHA_LINUX_X86="$(sha_for "kt-linux-x86_64.tar.gz")"
SHA_LINUX_ARM="$(sha_for "kt-linux-aarch64.tar.gz")"

if [ -z "$VERSION" ] || [ -z "$SHA_MACOS" ] || [ -z "$SHA_LINUX_X86" ] || [ -z "$SHA_LINUX_ARM" ]; then
    echo "error: could not extract version or SHA256 from manifest" >&2; exit 1
fi

echo "Version: ${VERSION}"
echo "  macOS universal : ${SHA_MACOS}"
echo "  Linux x86_64    : ${SHA_LINUX_X86}"
echo "  Linux aarch64   : ${SHA_LINUX_ARM}"

cat > "$FORMULA" <<RUBY
class Kt < Formula
  desc "Keeptrusts AI governance gateway CLI"
  homepage "https://keeptrusts.com"
  license :cannot_represent
  version "${VERSION}"

  on_macos do
    url "${DOWNLOAD_BASE}/releases/#{version}/kt-macos-universal.tar.gz"
    sha256 "${SHA_MACOS}"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "${DOWNLOAD_BASE}/releases/#{version}/kt-linux-aarch64.tar.gz"
      sha256 "${SHA_LINUX_ARM}"
    else
      url "${DOWNLOAD_BASE}/releases/#{version}/kt-linux-x86_64.tar.gz"
      sha256 "${SHA_LINUX_X86}"
    end
  end

  def install
    bin.install "kt"
  end

  test do
    assert_match "kt", shell_output("#{bin}/kt --version")
  end
end
RUBY

cd "$TAP_ROOT"
git add Formula/kt.rb
if git diff --cached --quiet; then
    echo "Formula already up to date (${VERSION})"
    exit 0
fi

git commit -m "kt ${VERSION}"
echo "Committed: kt ${VERSION}"

if [ "$DO_PUSH" = true ]; then
    git push origin HEAD
    echo "Pushed to origin"
fi
