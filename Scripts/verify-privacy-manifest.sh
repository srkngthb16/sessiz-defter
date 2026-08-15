#!/bin/bash
# Gizlilik manifestinin hem kaynakta hem derlenmiş uygulama paketinde
# bulunduğunu ve geçerli bir plist olduğunu doğrular.
# Kullanım: Scripts/verify-privacy-manifest.sh [derlenmis-app-yolu]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/App/PrivacyInfo.xcprivacy"
FAILED=0

if [ ! -f "$SOURCE" ]; then
  echo "FAIL · manifest yok: $SOURCE" >&2
  exit 1
fi

if ! plutil -lint "$SOURCE" >/dev/null; then
  echo "FAIL · manifest geçerli plist değil" >&2
  FAILED=1
fi

for KEY in NSPrivacyTracking NSPrivacyTrackingDomains NSPrivacyCollectedDataTypes \
           NSPrivacyAccessedAPITypes; do
  if ! plutil -extract "$KEY" raw -o - "$SOURCE" >/dev/null 2>&1; then
    echo "FAIL · manifestte eksik anahtar: $KEY" >&2
    FAILED=1
  fi
done

# İzleme ve veri toplama beyanı sessizce değişmemeli.
if [ "$(plutil -extract NSPrivacyTracking raw -o - "$SOURCE")" != "false" ]; then
  echo "FAIL · NSPrivacyTracking false olmalı" >&2
  FAILED=1
fi
if [ "$(plutil -extract NSPrivacyCollectedDataTypes raw -o - "$SOURCE" | tr -d '[:space:]')" != "0" ]; then
  echo "FAIL · NSPrivacyCollectedDataTypes boş olmalı" >&2
  FAILED=1
fi

APP="${1:-}"
if [ -n "$APP" ]; then
  if [ ! -f "$APP/PrivacyInfo.xcprivacy" ]; then
    echo "FAIL · manifest uygulama paketine kopyalanmamış: $APP" >&2
    FAILED=1
  else
    echo "OK · manifest uygulama paketinde"
  fi
fi

[ $FAILED -eq 0 ] && echo "OK · gizlilik manifesti geçerli"
exit $FAILED
