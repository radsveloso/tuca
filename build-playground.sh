#!/bin/sh
# Compila o Character Playground do Tuca e abre. Não mexe no app Tuca do notch.
set -e
cd "$(dirname "$0")"
swift build -c release --build-system native --product TucaPlayground
APP=build/TucaPlayground.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TucaPlayground "$APP/Contents/MacOS/TucaPlayground"
cp -R Resources/TucaCharacterArt "$APP/Contents/Resources/TucaCharacterArt"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.rafaelveloso.tuca.playground</string>
<key>CFBundleName</key><string>Tuca Playground</string>
<key>CFBundleExecutable</key><string>TucaPlayground</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>3.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force -s - "$APP"
[ "$1" = "--open" ] && open "$APP"
echo "$APP"
