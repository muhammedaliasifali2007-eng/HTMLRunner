#!/usr/bin/env bash
#
# make_ipa.sh — build a signed .ipa for HTML Runner. Run this on a Mac with
# Xcode 15+ (and, for the signing steps, your Apple ID added to Xcode).
#
#   ./tools/make_ipa.sh --team ABCDE12345 --bundle com.yourname.htmlrunner
#
# Options
#   --team    <TEAMID>   Apple Developer Team ID (Xcode → Settings → Accounts)
#   --bundle  <id>       Bundle identifier, e.g. com.yourname.htmlrunner
#                        (the extension automatically becomes <id>.share)
#   --group   <id>       App Group, default group.<bundle>
#   --method  <m>        development (default) | ad-hoc | app-store-connect
#                        development  → install on a device connected to your Mac
#                        ad-hoc       → install on registered devices by sharing the IPA
#                        app-store-connect → TestFlight / App Store
#   --scheme  <name>     default: HTMLRunner
#   --project <path>     default: ./HTMLRunner.xcodeproj
#
# Output: build/ipa/HTMLRunner.ipa  (plus the .xcarchive next to it)

set -euo pipefail

TEAM=""
BUNDLE=""
GROUP=""
METHOD="development"
SCHEME="HTMLRunner"
PROJECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team)    TEAM="$2"; shift 2 ;;
    --bundle)  BUNDLE="$2"; shift 2 ;;
    --group)   GROUP="$2"; shift 2 ;;
    --method)  METHOD="$2"; shift 2 ;;
    --scheme)  SCHEME="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
done

command -v xcodebuild >/dev/null || { echo "xcodebuild not found — run this on macOS with Xcode installed." >&2; exit 1; }

# Sensible defaults, discovered from the repo layout.
if [[ -z "$PROJECT" ]]; then
  PROJECT="$(find . -maxdepth 3 -name 'HTMLRunner.xcodeproj' -type d | head -n 1)"
fi
[[ -n "$PROJECT" ]] || { echo "HTMLRunner.xcodeproj not found; pass --project" >&2; exit 1; }

if [[ -z "$BUNDLE" ]]; then
  BUNDLE="$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = ' "$PROJECT/project.pbxproj" | sed 's/.*= //; s/;//')"
  echo "Using existing bundle id: $BUNDLE"
fi
[[ -n "$GROUP" ]] || GROUP="group.$BUNDLE"
if [[ -z "$TEAM" ]]; then
  TEAM="$(grep -m1 'DEVELOPMENT_TEAM = ' "$PROJECT/project.pbxproj" | sed 's/.*= //; s/;//' || true)"
fi
[[ -n "$TEAM" ]] || { echo "Pass --team <TEAMID> (Xcode → Settings → Accounts)." >&2; exit 1; }

BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/HTMLRunner.xcarchive"
EXPORT_DIR="$BUILD_DIR/ipa"
OLD_BUNDLE="$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER = ' "$PROJECT/project.pbxproj" | sed 's/.*= //; s/;//')"
OLD_GROUP="$(grep -m1 -o 'group\.[A-Za-z0-9._-]*' HTMLRunner/HTMLRunner.entitlements || echo 'group.com.example.htmlrunner')"

echo
echo "  bundle id      $OLD_BUNDLE  →  $BUNDLE   (extension: $BUNDLE.share)"
echo "  app group      $OLD_GROUP  →  $GROUP"
echo "  team           $TEAM"
echo "  method         $METHOD"
echo

# --- rewrite identifiers (safe to re-run: the script detects the current values)
python3 - "$PROJECT/project.pbxproj" "$OLD_BUNDLE" "$BUNDLE" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
if old == new:
    print("  (bundle id already correct)"); raise SystemExit
s = open(path).read()
open(path, "w").write(s.replace(old, new))
print(f"  patched {path}")
PY

for ent in HTMLRunner/HTMLRunner.entitlements ShareExtension/ShareExtension.entitlements; do
  [[ -f "$ent" ]] && sed -i '' "s|$OLD_GROUP|$GROUP|g" "$ent" && echo "  patched $ent"
done
if [[ -f Shared/SharedStore.swift ]]; then
  sed -i '' "s|static let appGroupID = \".*\"|static let appGroupID = \"$GROUP\"|" Shared/SharedStore.swift
  echo "  patched Shared/SharedStore.swift"
fi

echo "  bundle ids now:"
grep -m2 'PRODUCT_BUNDLE_IDENTIFIER' "$PROJECT/project.pbxproj" | sed 's/^/    /'

# --- archive ---------------------------------------------------------------
rm -rf "$ARCHIVE"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" \
  archive

# --- export ----------------------------------------------------------------
rm -rf "$EXPORT_DIR" && mkdir -p "$EXPORT_DIR"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>$METHOD</string>
	<key>teamID</key>
	<string>$TEAM</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>uploadSymbols</key>
	<true/>
	<key>compileBitcode</key>
	<false/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT_DIR" -name '*.ipa' | head -n 1)"
if [[ -n "$IPA" ]]; then
  echo
  echo "✓ IPA ready: $IPA"
  unzip -l "$IPA" | grep -i "PlugIns/" || true
  echo
  case "$METHOD" in
    development) echo "Install: connect the iPhone and drag the .ipa onto Xcode's Devices window, or use Apple Configurator." ;;
    ad-hoc)      echo "Install: share the .ipa with a registered device (Apple Configurator, link, or a distribution service)." ;;
    app-store-connect) echo "Upload: xcrun altool --upload-app --type ios --file \"$IPA\" --apiKey <KEY> --apiIssuer <ISSUER>" ;;
  esac
else
  echo "✗ export produced no IPA — check the xcodebuild output above." >&2
  exit 1
fi
