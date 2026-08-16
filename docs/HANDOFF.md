# Devir Notu — 2026-08-16

Önceki sohbet bağlam sınırına yaklaştı. Bu dosya işi kaldığı yerden sürdürmek için yazıldı.

## Durum

- **20 commit**, hepsi `origin/main`'de. HEAD: `fbd9f15`.
- **184 test geçiyor.** `./Scripts/test-all.sh`
- `Scripts/verify-offline.sh` yeşil, pre-commit hook'una bağlı.
- Uygulama simülatörde çalışıyor; Release yapılandırmasında da derlenip çalıştırıldı.
- Sürüm 1.0.0, build 2.

**Faz 0–7** ürün geliştirmesi (tasarım dosyalarına göre tüm ekranlar).
**Faz 8** yayın altyapısı — bitti.
**Faz 9.1, 9.2** — bitti.

## Sıradaki iş: Faz 9.3

TestFlight yayın hazırlığı planının kalan maddeleri:

**9.3 İlk kullanım**
- Onboarding sonunda "örnek veriyle gez": 20 sahte işlem yükler, Ayarlar'dan tek
  dokunuşla temizlenir. Örnek veri üreticisi Release'e sızmamalı — `#if DEBUG` değil,
  kullanıcıya açık bir özellik olacaksa üretim kodunda kalabilir ama ayırt edilebilir olmalı.
- B1 boş durum illüstrasyonunu tamamla. Şu an ekranda "Yer tutucu · ilk açılış görseli"
  yazıyor — App Store Guideline 2.1 riski, harici testten önce gitmeli.
- 13 gider + 3 gelir kategorisinin tamamı için SF Symbols eşleme tablosu, `docs/` altına.

**9.4 Geri bildirim yolu**
- Ayarlar'da "Geri bildirim gönder": cihaz modeli, iOS sürümü, uygulama sürümü ve
  anonim tanı bilgisi (işlem sayısı, hata sayacı). İçinde hiçbir işlem detayı, tutar,
  işyeri adı, hesap bilgisi olmayacak. Sistem paylaşım sayfası (`ShareLink`).
- Kullanıcı göndermeden önce metnin tamamını görsün.

**10.1 Erişilebilirlik** — VoiceOver ile her ekran, tutar okunuşu ("eksi 842 lira 60 kuruş"),
grafik özetleri, `docs/A11Y-AUDIT.md`.

**10.2 Performans** — 10.000 işlemlik defter üreten test yardımcısı; liste kaydırma,
dashboard açılış, rapor hesaplama, arama gecikmesi ölçümü. 250 ms üstü her işlem düzeltilir.

**10.3 Dayanıklılık** — yedek al/geri yükle simülatörde uçtan uca; uçak modu, düşük depolama,
içe aktarma sırasında uygulamayı öldürme, yarım kalan ImportBatch.

**11 App Store Connect paketi** — `docs/APPSTORE.md`, `docs/PRIVACY-POLICY.md`,
ekran görüntüsü planı ve üretimi.

## Kullanıcıdan bekleyenler

1. **Team ID** — Apple Developer üyeliği ödendi, onay bekleniyor. Gelince:
   `cp Config/Local.xcconfig.example Config/Local.xcconfig` ve Team ID yazılır.
   `Scripts/archive.sh` bunsuz çalışmaz.
2. **Gerçek ekstre** — Ziraat/Garanti/İş Bankası, anonimleştirilmiş. Kimlik bilgisi
   çıkarılmış ama tutar, tarih ve işyeri adları korunmuş olmalı. Fixture'lar sentetik.
3. **İhracat beyanı onayı** — `docs/EXPORT-COMPLIANCE.md` bölüm 4.
4. **Bundle ID doğrulaması** — `com.sessizdefter.app` Apple'da alınmamış mı.

## Çalışma kuralları

Ayrıntısı `docs/COWORK-BRIEFING.md` bölüm 1, 5 ve 7'de. Özet:

- Ağ katmanı yok, üçüncü parti bağımlılık yok. `verify-offline.sh` her commit'te yeşil.
- Brifing bölüm 5'teki kararlar normatif: gerekçesini okumadan geri alma, değiştirmen
  gerekiyorsa önce kullanıcıya sor.
- Tasarım dosyaları (`design/`) spesifikasyon. Çelişki ya da eksik varsa kullanıcıya sor,
  kendi kafana göre doldurma.
- Her faz kendi commit'i, Conventional Commits, tip İngilizce, açıklama Türkçe.
  Commit gövdesi "ne" değil "neden" yazar.
- Değişiklikler simülatörde de doğrulanır — dört gerçek hata yalnızca orada yakalandı.
- Her fazın sonunda dur: ne yapıldı, hangi testler geçti, kullanıcıdan ne gerekiyor.
