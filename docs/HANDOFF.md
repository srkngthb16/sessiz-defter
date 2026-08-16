# Devir Notu — 2026-08-16

Bu dosya işi kaldığı yerden sürdürmek için yazıldı.

## Durum

- **22 commit**, hepsi `origin/main`'de.
- **202 test geçiyor.** `./Scripts/test-all.sh`
- `Scripts/verify-offline.sh` yeşil, pre-commit hook'una bağlı.
- Uygulama simülatörde çalışıyor; Release yapılandırmasında da derlenip çalıştırıldı.
- Sürüm 1.0.0, build 2.
- **Team ID geldi** (2026-08-16): `Config/Local.xcconfig` içinde, derleme ayarlarında
  `DEVELOPMENT_TEAM` olarak görünüyor. Dosya gitignore'lu. `Scripts/archive.sh`
  TEAM_ID kapısını geçer — arşiv henüz üretilmedi.

**Faz 0–7** ürün geliştirmesi (tasarım dosyalarına göre tüm ekranlar).
**Faz 8** yayın altyapısı — bitti.
**Faz 9.1, 9.2, 9.3** — bitti.

## Faz 9.3'te ne yapıldı

1. **Örnek veri modu.** `Domain/Services/SampleLedger.swift` 20 sahte işlem +
   "Örnek Banka" hesabı + sabit kimlikli ImportBatch üretir.
   `Features/Settings/SampleDataService.swift` yükler ve temizler. Onboarding'in
   son sayfasında anahtar, Ayarlar > Veri'de "Örnek veriyi temizle".
2. **B1 illüstrasyonu.** `DesignSystem/Components/LedgerBoxArtwork.swift` —
   defter + kapalı kutu, tek çizgi, tek accent renk. Varlık dosyası değil Path:
   dört snapshot varyantında ve tema değişiminde kendisi dönüyor.
   Kaynak ağacında "Yer tutucu" metni kalmadı (Guideline 2.1 riski kapandı).
3. **SF Symbols eşlemesi.** `docs/CATEGORY-ICONS.md` 13 gider + 3 gelir için tam
   tablo ve gerekçeler. Tek kaynak `DefaultCategories`; Ayarlar'daki simge seçici
   de oradan türüyor. Üç eşleme değişti: Ulaşım `car → bus`, Abonelik
   `repeat → arrow.triangle.2.circlepath`, Eğitim `book → graduationcap`.

Simülatörde yakalanan üç hata (yalnızca orada görünürdü):
- Örnek veri onboarding'de yazıldığı için kategoriler henüz tohumlanmamıştı;
  20 işlemin tamamı "Kategorisiz" geliyordu. `SampleData.load` artık önce
  `seedDefaultCategoriesIfNeeded()` çağırıyor.
- Dashboard dağılım kartı limit dışı kalan kategorileri "Kategorisiz" diye
  yazıyordu (gerçekten kategorisiz harcamayla aynı satır). `CategoryBreakdownItem`
  artık `isRemainder` taşıyor, ekranda "Diğer kategoriler" yazıyor. İki nil
  kovasının kimliği de çakışıyordu — `id` artık metin.
- Örnek veri silinince defter hesapsız kalıyordu ("Nakit" hiç tohumlanmamış
  oluyordu, manuel giriş yapılamıyordu). `SampleData.clear` sonunda
  `seedDefaultAccountIfNeeded()` çağırıyor.

## Sıradaki iş: Faz 9.4

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

1. ~~Team ID~~ — geldi, yazıldı, doğrulandı.
2. **Bundle ID doğrulaması** — `com.sessizdefter.app` Apple'da alınmamış mı,
   App Store Connect'te kaydedilecek.
3. **Gerçek ekstre** — Ziraat/Garanti/İş Bankası, anonimleştirilmiş. Kimlik bilgisi
   çıkarılmış ama tutar, tarih ve işyeri adları korunmuş olmalı. Fixture'lar sentetik.
4. **İhracat beyanı onayı** — `docs/EXPORT-COMPLIANCE.md` bölüm 4.
5. **Destek URL'i ve gizlilik politikası URL'i** — App Store Connect'te zorunlu,
   yayınlanmış sayfa gerekiyor (GitHub Pages yeterli).

## Çalışma kuralları

Ayrıntısı `docs/COWORK-BRIEFING.md` bölüm 1, 5 ve 7'de. Özet:

- Ağ katmanı yok, üçüncü parti bağımlılık yok. `verify-offline.sh` her commit'te yeşil.
- Brifing bölüm 5'teki kararlar normatif: gerekçesini okumadan geri alma, değiştirmen
  gerekiyorsa önce kullanıcıya sor.
- Tasarım dosyaları (`design/`) spesifikasyon. Çelişki ya da eksik varsa kullanıcıya sor,
  kendi kafana göre doldurma.
- Her faz kendi commit'i, Conventional Commits, tip İngilizce, açıklama Türkçe.
  Commit gövdesi "ne" değil "neden" yazar. Devir notu ayrı `docs:` commit'i.
- Değişiklikler simülatörde de doğrulanır — yedi gerçek hata yalnızca orada yakalandı.
- Her fazın sonunda dur: ne yapıldı, hangi testler geçti, kullanıcıdan ne gerekiyor.
