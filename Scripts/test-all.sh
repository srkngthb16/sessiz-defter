#!/bin/bash
# Tüm paketlerin testleri. Paket test hedefleri .xcodeproj şemalarından görünmediği için
# her paket kendi dizininde, kendi şemasıyla çalıştırılır.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${SD_DEST:-platform=iOS Simulator,name=iPhone 17 Pro}"
DERIVED="$ROOT/DerivedData"
FAILED=0

for PKG in Core Domain Persistence ImportPipeline DesignSystem; do
  SCHEME="$PKG"
  case "$PKG" in DesignSystem|Domain) SCHEME="$PKG-Package";; esac
  echo "───── $PKG"
  ( cd "$ROOT/Packages/$PKG" && \
    xcodebuild test -scheme "$SCHEME" -destination "$DEST" -derivedDataPath "$DERIVED" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" 2>&1 \
    | grep -E "error:|✘|✔ Test run|Test run with" ) || FAILED=1
done

exit $FAILED
