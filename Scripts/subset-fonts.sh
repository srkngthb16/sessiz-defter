#!/bin/bash
# Gömülü fontları Türkçe kapsamına indirger. Kaynak TTF'ler Scripts/font-src/ altında
# tutulur; bu script çıktıyı DesignSystem kaynak ağacına yazar.
# fonttools bir build-time aracıdır, uygulama bağımlılığı değildir.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Scripts/font-src"
DST="$ROOT/Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts"
PYFTSUBSET="${PYFTSUBSET:-$ROOT/.venv-tools/bin/pyftsubset}"

if [ ! -x "$PYFTSUBSET" ]; then
  echo "pyftsubset yok. Kurulum: python3 -m venv .venv-tools && ./.venv-tools/bin/pip install fonttools brotli" >&2
  exit 1
fi

# Latin Basic + Latin-1 Supplement + Latin Extended-A (Türkçe ğışçöüİĞŞÇÖÜ buradan gelir)
# + ₺ (U+20BA) + tasarımda geçen tipografik işaretler: − (U+2212), … (U+2026),
# – — (U+2013,2014), tırnaklar, · (Latin-1'de).
UNICODES="U+0020-007E,U+00A0-00FF,U+0100-017F,U+20BA,U+2010-2015,U+2018-201D,U+2026,U+2039-203A,U+2212,U+FEFF"

for FILE in "$SRC"/*.ttf; do
  NAME="$(basename "$FILE")"
  "$PYFTSUBSET" "$FILE" \
    --output-file="$DST/$NAME" \
    --unicodes="$UNICODES" \
    --layout-features='*' \
    --no-hinting \
    --drop-tables+=DSIG,meta \
    --name-IDs='*' \
    --notdef-outline \
    --recommended-glyphs
  printf "%-28s %7s → %7s\n" "$NAME" \
    "$(stat -f%z "$FILE")" "$(stat -f%z "$DST/$NAME")"
done
