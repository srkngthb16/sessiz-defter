#!/bin/bash
# docs/APPSTORE.md içindeki mağaza metinlerinin karakter sınırlarını denetler.
#
# Neden betik: App Store Connect sınırı aşan metni kırpmıyor, kaydı reddediyor ve
# hatanın hangi alanda olduğunu söylemiyor. Metin dosyada düzenlendiğinde sınır
# burada, yükleme öncesinde görünsün.
#
# Sınırlar Apple'ın alan tanımlarından: ad ve alt başlık 30, tanıtım metni 170,
# anahtar kelimeler 100, açıklama 4000 karakter.
#
# archive.sh kapılarına bilerek eklenmedi: mağaza metni derlemeyi bloklamamalı.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOC="$ROOT/docs/APPSTORE.md"
FAILED=0

if [ ! -f "$DOC" ]; then
  echo "FAIL · $DOC yok" >&2
  exit 1
fi

# Başlığı verilen bölümün ilk kod bloğunu yazar.
block_after() {
  awk -v marker="$1" '
    index($0, marker) > 0 { found = 1; next }
    found && /^```/ { infence = !infence; if (!infence) exit; next }
    found && infence { print }
  ' "$DOC"
}

check() {
  local label="$1" marker="$2" limit="$3"
  local text count
  text="$(block_after "$marker")"
  if [ -z "$text" ]; then
    echo "FAIL · $label · metin bulunamadı (\"$marker\")"
    FAILED=1
    return
  fi
  # Son satır sonu sayılmasın: alana girilen metin onu taşımıyor.
  count=$(printf '%s' "$text" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')
  if [ "$count" -gt "$limit" ]; then
    echo "FAIL · $label · $count karakter, sınır $limit"
    FAILED=1
  else
    echo "OK   · $label · $count / $limit"
  fi
}

check "App Name"         "### App Name"         30
check "Subtitle"         "### Subtitle"         30
check "Promotional Text" "### Promotional Text" 170
check "Keywords"         "## 3. Keywords"       100
check "Description"      "## 4. Description"    4000

# Anahtar kelime alanında virgülden sonra boşluk bırakmak yer harcıyor: boşluk da
# karakter sayılıyor, arama eşleşmesine katkısı yok.
if block_after "## 3. Keywords" | grep -q ', '; then
  echo "FAIL · Keywords · virgülden sonra boşluk var"
  FAILED=1
fi

exit $FAILED
