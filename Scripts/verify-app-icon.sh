#!/bin/bash
# App Store alfa kanallı ikonu reddeder. İkonun boyutunu, alfa durumunu ve
# renk uzayını doğrular.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON="$ROOT/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
FAILED=0

if [ ! -f "$ICON" ]; then
  echo "FAIL · ikon yok: $ICON" >&2
  exit 1
fi

WIDTH=$(sips -g pixelWidth "$ICON" | awk '/pixelWidth/ {print $2}')
HEIGHT=$(sips -g pixelHeight "$ICON" | awk '/pixelHeight/ {print $2}')
if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
  echo "FAIL · ikon 1024x1024 olmalı, bulunan ${WIDTH}x${HEIGHT}" >&2
  FAILED=1
fi

HAS_ALPHA=$(sips -g hasAlpha "$ICON" | awk '/hasAlpha/ {print $2}')
if [ "$HAS_ALPHA" = "yes" ]; then
  echo "FAIL · ikonda alfa kanalı var; App Store reddeder" >&2
  echo "       düzeltme: sips -s format png --deleteColorManagementProperties" >&2
  FAILED=1
fi

SPACE=$(sips -g space "$ICON" | awk '/space/ {print $2}')
if [ "$SPACE" != "RGB" ]; then
  echo "UYARI · beklenmeyen renk uzayı: $SPACE" >&2
fi

[ $FAILED -eq 0 ] && echo "OK · ikon ${WIDTH}x${HEIGHT}, alfa yok, uzay $SPACE"
exit $FAILED
