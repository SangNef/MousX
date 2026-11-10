#!/bin/bash
# Build MousX.app (universal arm64 + x86_64).
# Dùng: ./build.sh            -> tạo build/MousX.app
#       ./build.sh install    -> build rồi cài vào /Applications và mở app
set -euo pipefail
cd "$(dirname "$0")"

APP="build/MousX.app"

echo "▸ Biên dịch..."
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MousX"

echo "▸ Đóng gói $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MousX"
cp Resources/Info.plist "$APP/Contents/Info.plist"

if [ ! -f build/AppIcon.icns ]; then
  echo "▸ Tạo icon..."
  ICONSET="build/AppIcon.iconset"
  rm -rf "$ICONSET"; mkdir -p "$ICONSET"
  swift scripts/make_icon.swift build/icon_1024.png 1024
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o build/AppIcon.icns
  rm -rf "$ICONSET" build/icon_1024.png
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ký bằng chứng chỉ thật (Apple Development / Developer ID) nếu có, để macOS nhận diện
# app ổn định qua các lần build => quyền Trợ năng không bị mất. Ghi đè bằng MOUSX_SIGN_ID.
SIGN_ID="${MOUSX_SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 -oE '"(Developer ID Application|Apple Development)[^"]*"' | tr -d '"' || true)}"
if [ -n "$SIGN_ID" ]; then
  echo "▸ Ký bằng chứng chỉ: $SIGN_ID"
  codesign --force --sign "$SIGN_ID" --identifier com.vscorp.MousX --timestamp=none "$APP"
else
  echo "▸ Ký ad-hoc (không có chứng chỉ — mỗi lần build lại phải cấp lại quyền Trợ năng)"
  codesign --force --sign - --identifier com.vscorp.MousX "$APP"
fi

if [ "${1:-}" = "install" ]; then
  echo "▸ Cài vào /Applications"
  pkill -x MousX 2>/dev/null || true
  rm -rf /Applications/MousX.app
  cp -R "$APP" /Applications/
  if [ "${2:-}" = "reset-permission" ]; then
    tccutil reset Accessibility com.vscorp.MousX >/dev/null 2>&1 || true
  fi
  open /Applications/MousX.app
fi

echo "✓ Xong: $APP"
