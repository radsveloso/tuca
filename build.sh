#!/bin/sh
# Compila o Tuca e monta o Tuca.app. Uso: ./build.sh [--install]
set -e
cd "$(dirname "$0")"
swift build -c release --build-system native
APP=build/Tuca.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Tuca "$APP/Contents/MacOS/Tuca"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Rig do Tuca (Character Engine 3.0), derivado do master aprovado
cp -R Resources/TucaCharacterArt "$APP/Contents/Resources/TucaCharacterArt"
codesign --force -s - "$APP"
if [ "$1" = "--install" ]; then
  pkill -x Tuca 2>/dev/null || true
  sleep 0.5
  rm -rf /Applications/Tuca.app
  cp -R "$APP" /Applications/Tuca.app
  open /Applications/Tuca.app
  echo "Instalado em /Applications/Tuca.app"
else
  echo "Pronto: $APP"
fi
