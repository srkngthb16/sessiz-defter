#!/bin/bash
# App Store Connect için arşiv üretir ve .ipa dışa aktarır.
# YÜKLEME YAPMAZ — çıktıyı Xcode Organizer ya da Transporter ile siz yüklersiniz.
#
# Gereken: Config/Local.xcconfig içinde TEAM_ID ve Xcode'a eklenmiş Apple hesabı.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${SD_BUILD_DIR:-$ROOT/build}"
ARCHIVE="$BUILD_DIR/SessizDefter.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

TEAM_ID="${TEAM_ID:-$(grep -E '^TEAM_ID' Config/Local.xcconfig 2>/dev/null | sed 's/.*= *//' | tr -d '[:space:]' || true)}"
if [ -z "$TEAM_ID" ]; then
  echo "FAIL · TEAM_ID yok." >&2
  echo "       cp Config/Local.xcconfig.example Config/Local.xcconfig" >&2
  echo "       ve Team ID'nizi yazın (developer.apple.com · Membership Details)." >&2
  exit 1
fi

# Kapılar: biri düşerse arşiv üretilmez. Yayınlanan yapı test edilmemiş olamaz.
echo "───── çevrimdışılık doğrulaması"
"$ROOT/Scripts/verify-offline.sh"
echo "───── gizlilik manifesti"
"$ROOT/Scripts/verify-privacy-manifest.sh"
echo "───── uygulama ikonu"
"$ROOT/Scripts/verify-app-icon.sh"
echo "───── testler"
"$ROOT/Scripts/test-all.sh"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE" "$EXPORT_DIR"

# Profil ya da sertifika üretilmesi gerekiyorsa (ilk arşiv) bu kapı açılır:
#   SD_ALLOW_PROVISIONING=1 ./Scripts/archive.sh
# Varsayılan kapalı: Apple hesabında sertifika ve profil yaratmak kalıcı bir iş,
# arşiv betiğinin sessizce yapacağı şey değil.
PROVISIONING_ARGS=()
if [ "${SD_ALLOW_PROVISIONING:-0}" = "1" ]; then
  PROVISIONING_ARGS+=(-allowProvisioningUpdates)
  echo "NOT · otomatik profil güncellemesi açık; gerekirse sertifika/profil üretilecek"
fi

# Arşiv imzalı üretilir; dağıtım imzası export adımında yeniden biniyor. Bu,
# Xcode'un standart akışı ve Apple'ın doğruladığı tek yol.
#
# Bir ara "imzasız arşivle, export imzalasın" denendi: arşiv ve export başarılı
# oluyor, ama Transporter ikiliyi reddediyor —
# "Invalid Signature. Code failed to satisfy specified code requirement(s)".
# İmzasız arşivi export'un yeniden imzalaması, yerel dağıtım sertifikası
# olmadığında bulut imzalamaya düşüyor ve ortaya çıkan mühür geçerli sayılmıyor.
# Bedeli: arşiv adımı geliştirme profili istediği için takımda kayıtlı en az bir
# cihaz gerekiyor.
echo "───── arşivleniyor"
xcodebuild archive \
  -project SessizDefter.xcodeproj \
  -scheme SessizDefter \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  ${PROVISIONING_ARGS[@]+"${PROVISIONING_ARGS[@]}"} \
  DEVELOPMENT_TEAM="$TEAM_ID"

cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$TEAM_ID</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<!-- Bitcode yıllar önce kaldırıldı; App Store Connect kabul etmiyor. -->
	<key>compileBitcode</key>
	<false/>
	<!-- Uygulama tek dil taşıyor; ek dil kırpması gerekmiyor. -->
	<key>stripSwiftSymbols</key>
	<true/>
</dict>
</plist>
PLIST

echo "───── dışa aktarılıyor (dağıtım imzası burada biniyor)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  ${PROVISIONING_ARGS[@]+"${PROVISIONING_ARGS[@]}"}

echo
echo "OK · arşiv:  $ARCHIVE"
echo "OK · çıktı:  $EXPORT_DIR"
ls -la "$EXPORT_DIR" 2>/dev/null || true
echo
echo "Yükleme adımı bu script'te yok. İki yol:"
echo "  1) Xcode · Window · Organizer · Archives · $ARCHIVE · Distribute App"
echo "  2) Transporter uygulaması · $EXPORT_DIR içindeki .ipa dosyasını sürükle"
