#!/bin/bash
# Builds "SomAt Dev - Clean Mac Dev.app" and packages it as installers in the "dist" folder:
#   CleanMacDev-<version>.dmg  - open it and drag the app into Applications
#   CleanMacDev-<version>.pkg  - double-click to install into /Applications
# Needs Xcode or the Command Line Tools (xcode-select --install).
#
# Optional, for sharing with other Macs without security warnings:
#   - A "Developer ID Application" certificate in your keychain is used to sign the app and .dmg.
#   - A "Developer ID Installer" certificate is used to sign the .pkg.
#   - A notarytool profile named "CleanMacDev" is used to notarize, created once with:
#       xcrun notarytool store-credentials CleanMacDev --apple-id YOU@EXAMPLE.COM --team-id TEAMID

cd "$(dirname "$0")" || exit 1

NAME="SomAt Dev - Clean Mac Dev"
SHORT_NAME="Clean Mac Dev"
EXE="CleanMacDev"
VERSION="${VERSION:-1.1.0}"
BUNDLE_ID="dev.somat.cleanmacdev"
NOTARY_PROFILE="CleanMacDev"
DMG="CleanMacDev-$VERSION.dmg"
PKG="CleanMacDev-$VERSION.pkg"

DIST="$PWD/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/$NAME.app"

step() { echo; echo "==> $1"; }
fail() { echo; echo "ERROR: $1"; echo "Copy the lines above and send them to Claude."; exit 1; }

# ---- 1. Compile ----------------------------------------------------------
step "Checking for the Swift compiler"
if ! xcrun --sdk macosx --find swiftc >/dev/null 2>&1; then
  echo "The Swift compiler was not found."
  echo "Install the Command Line Tools with:  xcode-select --install"
  exit 1
fi

SOURCES=()
while IFS= read -r file; do SOURCES+=("$file"); done < <(find Sources/CleanMacDev -name '*.swift' | sort)

compile() {   # $1 = arch
  xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -O -module-name CleanMacDev \
    -target "$1-apple-macos13.0" "${SOURCES[@]}" -o "$WORK/$EXE-$1"
}

step "Compiling for Apple Silicon"
compile arm64 || fail "Compiling for Apple Silicon failed."

step "Compiling for Intel Macs"
if compile x86_64; then
  lipo -create "$WORK/$EXE-arm64" "$WORK/$EXE-x86_64" -output "$WORK/$EXE" || fail "lipo failed."
  echo "Universal app (Apple Silicon + Intel)."
else
  echo "Intel build failed, making an Apple Silicon-only app."
  cp "$WORK/$EXE-arm64" "$WORK/$EXE"
fi

# ---- 2. App bundle -------------------------------------------------------
step "Creating $NAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$WORK/$EXE" "$APP/Contents/MacOS/$EXE"

ICON_KEY=""
if [ -f assets/icon.png ] && command -v iconutil >/dev/null 2>&1; then
  SET="$WORK/AppIcon.iconset"
  mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s assets/icon.png --out "$SET/icon_${s}x${s}.png" >/dev/null 2>&1
    d=$((s * 2))
    sips -z $d $d assets/icon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null 2>&1
  done
  if iconutil -c icns "$SET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
  fi
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$SHORT_NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXE</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Clean Mac Dev asks Finder to empty the Trash.</string>
  $ICON_KEY
</dict>
</plist>
PLIST

cat > "$WORK/entitlements.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.automation.apple-events</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP" 2>/dev/null

# ---- 3. Sign -------------------------------------------------------------
step "Signing"
APP_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)".*/\1/')
INST_ID=$(security find-identity -v 2>/dev/null | grep "Developer ID Installer" | head -1 | sed -E 's/.*"(.*)".*/\1/')

if [ -n "$APP_ID" ]; then
  echo "Using: $APP_ID"
  codesign --force --options runtime --timestamp \
    --entitlements "$WORK/entitlements.plist" -s "$APP_ID" "$APP" || fail "Signing failed."
else
  echo "No Developer ID certificate found: signing for this Mac only (ad-hoc)."
  codesign --force -s - "$APP" >/dev/null 2>&1
fi

# ---- 4. Disk image (.dmg) ------------------------------------------------
step "Making $DMG"
mkdir -p "$DIST"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DIST/$DMG"
hdiutil create -volname "$SHORT_NAME" -srcfolder "$STAGE" -ov -format UDZO \
  "$DIST/$DMG" >/dev/null || fail "Making the .dmg failed."
[ -n "$APP_ID" ] && codesign --force --timestamp -s "$APP_ID" "$DIST/$DMG"

# ---- 5. Installer package (.pkg) -----------------------------------------
step "Making $PKG"
ROOT="$WORK/pkgroot"
mkdir -p "$ROOT"
cp -R "$APP" "$ROOT/"
# Always install into /Applications, even if a copy exists somewhere else.
pkgbuild --analyze --root "$ROOT" "$WORK/component.plist" >/dev/null 2>&1
plutil -replace 0.BundleIsRelocatable -bool NO "$WORK/component.plist" 2>/dev/null
rm -f "$DIST/$PKG"
PKG_ARGS=(--root "$ROOT" --component-plist "$WORK/component.plist"
          --install-location /Applications --identifier "$BUNDLE_ID" --version "$VERSION")
[ -n "$INST_ID" ] && PKG_ARGS+=(--sign "$INST_ID" --timestamp)
pkgbuild "${PKG_ARGS[@]}" "$DIST/$PKG" >/dev/null || fail "Making the .pkg failed."

# ---- 6. Notarize (only if set up) ----------------------------------------
if [ -n "$APP_ID" ] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  step "Notarizing with Apple (takes a few minutes)"
  if xcrun notarytool submit "$DIST/$DMG" --keychain-profile "$NOTARY_PROFILE" --wait; then
    xcrun stapler staple "$DIST/$DMG"
  else
    echo "Notarizing the .dmg failed; it still works on this Mac."
  fi
  if [ -n "$INST_ID" ]; then
    if xcrun notarytool submit "$DIST/$PKG" --keychain-profile "$NOTARY_PROFILE" --wait; then
      xcrun stapler staple "$DIST/$PKG"
    else
      echo "Notarizing the .pkg failed; it still works on this Mac."
    fi
  fi
fi

# ---- Done ----------------------------------------------------------------
step "Done"
echo "  $DIST/$DMG   (open it, drag the app into Applications)"
echo "  $DIST/$PKG   (double-click to install)"
if [ -z "$APP_ID" ]; then
  echo
  echo "Not signed with a Developer ID: fine on this Mac. On other Macs,"
  echo "right-click the app > Open the first time (or System Settings >"
  echo "Privacy & Security > Open Anyway)."
fi
[ -z "$CI" ] && open "$DIST"
exit 0
