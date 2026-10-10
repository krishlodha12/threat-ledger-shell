#!/usr/bin/env bash
# Builds an UNSIGNED iOS app (.ipa) with swiftc directly: no Xcode project, no signing,
# no secrets. Signing happens later on the owner's PC with their own Apple ID (forge).
#
# Usage: scripts/build-unsigned.sh <output-dir>
set -euo pipefail

OUT="$(mkdir -p "${1:-build}" && cd "${1:-build}" && pwd)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME=TLShell
MIN_IOS=17.0
SDK=iphoneos

cd "$ROOT"
# Fixed timestamps and build number come from the commit, so two builds of one commit match.
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct)}"
export ZERO_AR_DATE=1
BUILD_NUMBER="$(git rev-list --count HEAD)"

SDK_PATH="$(xcrun --sdk $SDK --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk $SDK --show-sdk-version)"
SDK_BUILD="$(xcrun --sdk $SDK --show-sdk-build-version)"
XCODE_VERSION="$(xcodebuild -version | awk '/^Xcode/{print $2}')"
XCODE_BUILD="$(xcodebuild -version | awk '/Build version/{print $3}')"
# DTXcode is the version without dots, padded: 26.0.1 -> 2601, 27.0 -> 2700
IFS=. read -r XMAJ XMIN XPATCH <<<"$XCODE_VERSION"
DTXCODE="$(printf '%d%d%d' "$XMAJ" "${XMIN:-0}" "${XPATCH:-0}")"

STAGE="$OUT/stage"
APP="$STAGE/Payload/$APP_NAME.app"
rm -rf "$STAGE" && mkdir -p "$APP"

echo "== Compiling with Xcode $XCODE_VERSION ($XCODE_BUILD), iOS SDK $SDK_VERSION, deployment target $MIN_IOS"
xcrun --sdk $SDK swiftc \
  -target "arm64-apple-ios$MIN_IOS" \
  -sdk "$SDK_PATH" \
  -O -whole-module-optimization \
  -parse-as-library \
  -module-name "$APP_NAME" \
  Sources/*.swift \
  -o "$APP/$APP_NAME"

cp Resources/*.png "$APP/"
cp Info.plist "$APP/Info.plist"
set_key() { plutil -replace "$1" -string "$2" "$APP/Info.plist"; }
set_key CFBundleVersion "$BUILD_NUMBER"
set_key DTPlatformName iphoneos
set_key DTPlatformVersion "$SDK_VERSION"
set_key DTPlatformBuild "$SDK_BUILD"
set_key DTSDKName "iphoneos$SDK_VERSION"
set_key DTSDKBuild "$SDK_BUILD"
set_key DTXcode "$DTXCODE"
set_key DTXcodeBuild "$XCODE_BUILD"
set_key DTCompiler com.apple.compilers.llvm.clang.1_0
plutil -convert binary1 "$APP/Info.plist"
plutil -lint "$APP/Info.plist"
printf 'APPL????' > "$APP/PkgInfo"
chmod 0644 "$APP"/*.png "$APP/Info.plist" "$APP/PkgInfo"
chmod 0755 "$APP/$APP_NAME"

echo "== Checking the bundle"
ARCHS="$(lipo -archs "$APP/$APP_NAME")"
[ "$ARCHS" = "arm64" ] || { echo "unexpected architectures: $ARCHS"; exit 1; }
otool -l "$APP/$APP_NAME" | grep -A4 LC_BUILD_VERSION | grep -E "platform|minos|sdk"
[ ! -e "$APP/_CodeSignature" ] || { echo "bundle is signed, expected unsigned"; exit 1; }
[ ! -e "$APP/embedded.mobileprovision" ] || { echo "bundle carries a profile"; exit 1; }
echo "codesign says: $(codesign -dv "$APP" 2>&1 | head -1 || true)"

IPA="$OUT/$APP_NAME-unsigned.ipa"
python3 "$ROOT/scripts/zip_deterministic.py" "$STAGE" "$IPA"

{
  echo "app:            $APP_NAME ($(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")) build $BUILD_NUMBER"
  echo "commit:         $(git rev-parse HEAD)"
  echo "xcode:          $XCODE_VERSION ($XCODE_BUILD)"
  echo "ios sdk:        $SDK_VERSION ($SDK_BUILD)"
  echo "deployment:     iOS $MIN_IOS"
  echo "binary sha256:  $(shasum -a 256 "$APP/$APP_NAME" | cut -d' ' -f1)"
  echo "ipa sha256:     $(shasum -a 256 "$IPA" | cut -d' ' -f1)"
  echo "signed:         no"
} > "$OUT/BUILD-INFO.txt"
cat "$OUT/BUILD-INFO.txt"
