# Sessiz Defter

iOS 17+ kişisel finans defteri. Banka PDF ekstresi cihaz üzerinde ayrıştırılır, işlemler
otomatik kategorilenir. Ağ katmanı yoktur — eklenmemiştir, kapatılabilir bir ayar değildir.

## Kısıtlar
- `URLSession`, `Network`, `CloudKit`, analytics/crash SDK'sı yok; Info.plist'te ağ anahtarı yok.
- SwiftData ModelContainer CloudKit kapalı, `.none` sync.
- Dosyalar `FileProtection.complete`; hassas alan anahtarları Keychain'de
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Hesap/giriş/e-posta yok. Tek koruma LocalAuthentication.
- BackgroundTask yok.
- Üçüncü parti bağımlılık yok. Tek istisna: gömülü Archivo + IBM Plex Mono (SIL OFL).

## Modüller
```
App ──► DesignSystem ──► Core
    ├─► ImportPipeline ─► Domain ─► Core
    └─► Domain
```
`Domain` saf Swift'tir; SwiftData/SwiftUI import etmez. Kural `DomainTests/ArchitectureTests` ile test edilir.

## Komutlar
Derleme:
```
xcodebuild build -project SessizDefter.xcodeproj -scheme SessizDefter -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```
Tüm testler:
```
./Scripts/test-all.sh
```
Çevrimdışılık doğrulaması (CI + pre-commit):
```
./Scripts/verify-offline.sh
```
Snapshot referansı yoksa ilk çalıştırma referansı yazar ve düşer; ikinci çalıştırma karşılaştırır.
Referansı bilerek güncellemek için `__Snapshots__` altındaki ilgili PNG silinir ve testler
iki kez çalıştırılır.

## Git hook
`git config core.hooksPath .githooks` bu depoda ayarlıdır; her commit'te `verify-offline.sh` çalışır.
