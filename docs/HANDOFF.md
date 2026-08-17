# Devir Notu — 2026-08-17

Bu dosya işi kaldığı yerden sürdürmek için yazıldı.

## Durum

- **39 commit**; son dördü (`6452a5d`…) henüz `origin/main`'e itilmedi.
- **247 test geçiyor.** `./Scripts/test-all.sh`
- `Scripts/verify-offline.sh` yeşil, pre-commit hook'una bağlı.
- Uygulama simülatörde çalışıyor; Release yapılandırmasında da derlenip çalıştırıldı.
- Sürüm 1.0.0, build 2.
- **Team ID geldi** (2026-08-16): `Config/Local.xcconfig` içinde, derleme ayarlarında
  `DEVELOPMENT_TEAM` olarak görünüyor. Dosya gitignore'lu. `Scripts/archive.sh`
  TEAM_ID kapısını geçer — arşiv henüz üretilmedi.

**Faz 0–7** ürün geliştirmesi (tasarım dosyalarına göre tüm ekranlar).
**Faz 8** yayın altyapısı — bitti.
**Faz 9.1 – 9.4, 10.1 – 10.3** — bitti.

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

## Faz 9.4'te ne yapıldı

- **Geri bildirim ekranı.** Ayarlar > Geri bildirim gönder
  (`Features/Settings/FeedbackView.swift`). Paylaşılacak metnin tamamı ekranda,
  altında `ShareLink`. Metni `FeedbackReport` üretir: uygulama sürümü, cihaz model
  kodu, iOS sürümü, işlem/hesap/bütçe **sayısı** ve hata sayacı. Tutar, işyeri adı,
  hesap adı, dosya adı ya da hata metni girmiyor; test bunu yasaklı sözcük listesiyle
  denetliyor.
- **Anonim hata sayacı** (`Features/Settings/Diagnostics.swift`). Üç sayaç: veri
  okuma, içe aktarma, yedekleme. Dashboard/İşlemler/Bütçe/Raporlar hata dalları ve
  yedek akışı yazıyor. Hata metni saklanmıyor. Zayıf parola gibi kullanıcı hataları
  sayaca girmiyor. "Tüm verileri sil" sayacı sıfırlıyor.
- Sayaç `AppEnvironment.diagnostics` üzerinden geçiyor; testte ayrı UserDefaults
  süiti veriliyor, üretim sayacına dokunulmuyor.
- Cihaz model kodu (`iPhone17,5`) pazarlama adı yerine `uname`'den; simülatörde
  `SIMULATOR_MODEL_IDENTIFIER`.

Simülatörde doğrulandı: metin ekranda tam görünüyor, paylaşım sayfası açılıyor,
sayaçlar 0 iken de satırlar yazılıyor.

## Faz 10.1'de ne yapıldı

Ayrıntısı `docs/A11Y-AUDIT.md`. Özet:

- **Tutar okunuşu** (`Core/Fmt.spoken`): "eksi 842 lira 60 kuruş". Kuruş sıfırsa
  okunmuyor. Yüzde de sözcükle: "yüzde 93".
- **Ekran etiketleri**: bakiye kartı, bütçe kartı, dağılım satırı, işlem satırı ve
  gün başlığı tek cümleye indirildi. Hesap maskesi "••3412" artık "son dört hane
  3412" diye okunuyor.
- **Grafik özeti**: trend grafiği tek öğe, değeri "3 dönem. En yüksek gider Tem…"
  biçiminde sözlü özet.
- **XXXL yerleşim** (simülatörde yakalandı): dashboard ve raporlarda tutarlar
  "+₺ 25.…" diye kırpılıyordu. `DesignSystem/AdaptiveStack` erişilebilirlik
  kademesinde yan yana tutarları alt alta alıyor.

**Kalan:** VoiceOver ile gerçek cihazda uçtan uca gezinme — simülatörde betikle
sürülemedi, kullanıcının bir tur atması gerekiyor (`docs/A11Y-AUDIT.md`,
"Açık kalanlar").

## Faz 10.2'de ne yapıldı

Ayrıntısı `docs/PERFORMANCE.md`. Özet: 10.000 kayıtlık ölçüm yardımcısı
(`DomainTestSupport/LargeLedger`), altı ölçüm testi, beş düzeltme.

| İşlem | Önce | Sonra |
|---|---|---|
| 10.000 kayıt yazımı | ~130 s | ~1,5 s |
| Liste (ilk sayfa) | 456 ms | eşik altı |
| Arama | 718 ms | eşik altı |
| Sayım | 458 ms | eşik altı |
| Dashboard (sekme değişimi) | ~450 ms | eşik altı |

- `upsertAll` kayıt başına sorgu atmayı bıraktı (en büyük kazanç).
- Arama `searchIndex` sütunuyla store tarafına indi; sütun açılışta bir kez geri
  doldurulur.
- İşlem listesi 200'er satır, sona gelince devamı yükleniyor.
- Dashboard defterin tamamını okumuyor; net varlık hesap toplamlarından, toplam
  önbellekte, her yazma düşürüyor.
- `Fmt` biçimlendiricileri tek örneğe alındı.

**Simülatörde yakalanan hata:** arama hiçbir şey bulmuyordu — `searchIndex` sonradan
eklendiği için eski satırlarda NULL kalıyor, `isEmpty` yüklemi onları görmüyordu.
Geri doldurma artık satırları okuyup karşılaştırıyor.

**Karar bekleyen:** net varlığın ilk hesabı 10.000 kayıtta ~460 ms. iOS 17
SwiftData'da toplama sorgusu yok. Ya denormalize toplam tablosu yazılacak
(tutarlılık riski) ya da şimdiki hâl kabul edilecek (açılışta tek sefer, B2
iskeleti örtüyor).

## Faz 10.3'te ne yapıldı

Ayrıntısı `docs/RESILIENCE.md`. Beş senaryo:

| Senaryo | Durum |
|---|---|
| Yedek al / geri yükle | Simülatörde uçtan uca doğrulandı (dışa aktar, defteri boşalt, geri yükle: 20 işlem, 2 bütçe, hesap geri geldi) |
| İçe aktarma sırasında ölüm | İki aşamalı yazma + açılışta onarım; simülatörde depo elle yarım bırakılıp doğrulandı |
| Yarım kalan ImportBatch | Onarım işlem silmiyor, gerçek sayıyla tamamlıyor; arşiv uyumluluğu testli |
| Uçak modu | Yapı gereği (ağ kodu yok, `verify-offline.sh` denetliyor) |
| Düşük depolama | Kısmen: hata yolları tanımlı, gerçek disk dolu üretilemedi |

**Kullanıcı cihazda doğruladı:** yedek dışa aktarma ve geri yükleme sorunsuz.

**Cihazda çıkan hata düzeltildi:** "Tüm verileri sil" onayı "SİL" ile tam eşleşme
arıyordu; klavye "SIL" (noktasız I) üretiyor ve buton hiç açılmıyordu. Artık
Türkçe harf katlamasıyla karşılaştırılıyor (`String.trFoldedUpper`).

**Kalan elle deneme:** düşük depolama (cihazda disk doluyken yedek/içe aktarma).

## Faz 11'de ne yapıldı

Dört yeni belge, üç yeni betik, bir test yalıtım düzeltmesi.

**Belgeler**
- `docs/APPSTORE.md` — App Store Connect'in her alanı: ad, alt başlık, tanıtım
  metni, anahtar kelimeler, açıklama, "Yenilikler", kategori, yaş sınırı anketi,
  App Privacy cevapları, App Review notları, fiyat/kullanılabilirlik, yükleme
  kontrol listesi. Her değerin yanında gerekçesi var.
- `docs/PRIVACY-POLICY.md` — yayınlanabilir gizlilik politikası. "Veri
  toplanmıyor" iddia olarak değil, kullanıcının kendi sınayabileceği üç yolla
  yazıldı (uçak modu, uygulama içi mahremiyet raporu, açık kaynak + denetim
  betiği).
- `docs/SUPPORT.md` — App Store Connect'in zorunlu tuttuğu destek sayfası.
  E-posta adresi **boş**, kullanıcı dolduracak.
- `docs/SCREENSHOTS.md` — plan, boyutlar, hangi ekran neden seçildi, üretim
  adımları ve simülatörde çıkan üç tuzak.

**Betikler**
- `Scripts/verify-appstore-limits.sh` — mağaza metinlerinin karakter sınırları.
  Hepsi sınır altında: ad 13/30, alt başlık 26/30, tanıtım 149/170, anahtar
  kelimeler 94/100, açıklama 2580/4000.
- `Scripts/make-screenshots.swift` — ham çekime başlık bandı biner, 1320×2868
  çıktı üretir; girdi ölçüsü yanlışsa durur.
- `Scripts/make-sample-statement.swift` — App Review'a eklenecek örnek ekstre
  PDF'i (kurgusal banka, "ÖRNEK BELGE" damgalı).

**App Privacy ↔ manifest eşlemesi** `docs/APPSTORE.md` bölüm 8.1'de satır satır:
dört manifest anahtarının üçü forma karşılık geliyor, `NSPrivacyAccessedAPITypes`
ise ayrı mekanizma (required reason API), formda karşılığı yok.

**Ekran görüntüleri** iPhone 17 Pro Max simülatöründe, örnek defterle çekildi;
altı kare `build/screenshots/appstore` altında (gitignore'lu, betikle yeniden
üretilir).

**Arşiv denemesi:** dört kapı da geçti (çevrimdışılık, gizlilik manifesti, ikon,
247 test) — arşiv imzalamada düştü, çünkü bundle ID hesapta kayıtlı değil:

```
error: No profiles for 'com.sessizdefter.app' were found
```

**Simülatörde yakalanan iki şey:** `Toggle` anlık dokunuşu yutuyor (~150 ms
basılı kalmalı), bildirim izni istemi Bütçe sekmesinde çıkıp kareyi kaplıyor.
İkisi de `docs/SCREENSHOTS.md` bölüm 5.3'te.

**Test yalıtımı düzeltildi:** hata sayacı testleri tam koşuda düşüyor, tek
başına geçiyordu. `UserDefaults(suiteName:)` arama listesine uygulamanın kendi
alanını da katıyor; ayrı süit vermek yalıtım sağlamıyordu. Sayaç anahtarına
isteğe bağlı önek eklendi (üretimde boş).

## Sıradaki iş: Faz 12 — yayın

App Store Connect kaydı açılır, metinler girilir, arşiv üretilip yüklenir,
TestFlight iç testi yapılır. Adım listesi `docs/APPSTORE.md` bölüm 14'te.

## Kullanıcıdan bekleyenler

1. ~~Team ID~~ — geldi, yazıldı, doğrulandı.
2. **Xcode'da Apple hesabı yok — arşivi bloklayan ilk şey.**
   `SD_ALLOW_PROVISIONING=1` ile denendi, çıkan hata:
   `No Accounts: Add a new account in Accounts settings.`
   Xcode > Settings > Accounts > + > Apple ID ile hesap eklenmeli.
3. **Bundle ID kaydı.** Hesap eklendikten sonra ya developer.apple.com >
   Identifiers'tan `com.sessizdefter.app` elle kaydedilir, ya da
   `SD_ALLOW_PROVISIONING=1 ./Scripts/archive.sh` ile Xcode kaydeder. İkincisi
   hesapta kalıcı App ID yaratır, o yüzden varsayılan değil.
4. **Destek e-posta adresi** — `docs/SUPPORT.md` ve `docs/PRIVACY-POLICY.md`
   bölüm 11 boş bekliyor; App Store Connect'teki adresle aynı olmalı.
5. **GitHub Pages'i aç** — Settings > Pages > main dalı, `/docs` klasörü.
   Sonra iki URL App Store Connect'e girilir.
6. **İhracat beyanı onayı** — `docs/EXPORT-COMPLIANCE.md` bölüm 4.
7. **Gerçek ekstre** — Ziraat/Garanti/İş Bankası, anonimleştirilmiş. Kimlik bilgisi
   çıkarılmış ama tutar, tarih ve işyeri adları korunmuş olmalı. Fixture'lar sentetik.
8. **Son commit'ler itilmedi** — `git push` sende.

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
