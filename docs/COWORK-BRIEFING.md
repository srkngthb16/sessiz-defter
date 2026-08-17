# Sessiz Defter — Proje Brifingi

iOS 17+ kişisel finans defteri. Banka PDF ekstresi cihaz üzerinde ayrıştırılır,
işlemler otomatik kategorilenir. Tamamen çevrimdışı. Yedi geliştirme fazı bitti,
App Store yayını için hazırlık aşamasında.

Bu dosya kodu görmeden karar verebilmek için yazıldı: mimari, kısıtlar, verilen
kararlar ve gerekçeleri, bilinen eksikler.

---

## 1. Bozulamaz kısıtlar

Bunlar ayar değil, mimarinin kendisi. Hiçbiri gevşetilmedi.

| Kısıt | Durum |
|---|---|
| Ağ katmanı yok | `URLSession`, `Network`, `CloudKit`, analytics/crash SDK'sı yok. Info.plist'te ağ anahtarı yok. |
| SwiftData CloudKit kapalı | `cloudKitDatabase: .none`, test ile doğrulanıyor. |
| FileProtection.complete | Store dosyası ve `-wal`/`-shm` yan dosyaları dahil. |
| Keychain | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. |
| Hesap/giriş/e-posta yok | Tek koruma `LocalAuthentication` (Face ID + cihaz parolası). |
| BackgroundTask yok | Arka planda hiçbir iş çalışmaz. |
| Üçüncü parti bağımlılık yok | Yalnız Apple framework'leri. |

**İzin verilen framework'ler:** SwiftUI, SwiftData, PDFKit, Vision, NaturalLanguage,
LocalAuthentication, Charts, UniformTypeIdentifiers, CryptoKit, CommonCrypto,
UserNotifications, Security.

**Sonradan eklenenler (kullanıcı onayıyla):**
- `UserNotifications` — bütçe eşiği bildirimi. Tek dosyada toplandı
  (`Features/Budgets/BudgetNotifications.swift`), başka dosyada kullanımı
  `verify-offline.sh` ile build hatası yapılıyor.
- `CommonCrypto` — PBKDF2. Gerekçe aşağıda (bölüm 5).

**Tek istisna:** Archivo + IBM Plex Mono fontları (SIL OFL) bundle'a gömülü.

---

## 2. Mimari

```
App  ──►  Features  ──►  DesignSystem  ──►  Core
              ├──────►  Domain  ──►  Core
              └──────►  Persistence  ──►  Domain
        ImportPipeline  ──►  Domain, Core
```

Sekiz SPM paketi (`Packages/` altında) + `App` hedefi (`SessizDefter.xcodeproj`).

| Paket | İçerik |
|---|---|
| `Core` | `Money` (Int kuruş), tr_TR biçimlendirme (`Fmt`), `DuplicateHash`, `PasswordCrypto`, `Keychain`, `AppLock` |
| `Domain` | Saf Swift varlıklar, Repository protokolleri, `TransactionService`, `BudgetEngine`, `ReportBuilder`, `CategorizationEngine`, `Balances` |
| `DomainTestSupport` | Bellek içi repository gerçeklemeleri |
| `Persistence` | SwiftData `@Model` sınıfları, `PersistenceStore` (`@ModelActor`), mapping, `StoreFactory`, `BackupService` |
| `ImportPipeline` | Parser'lar, `BankFormatDetector`, `DraftBuilder`, `PDFTextExtractor`, `ImportPipeline` |
| `DesignSystem` | Renk/font tokenları, bileşenler, `SnapshotSupport` (elde yazılmış snapshot altyapısı) |
| `Features` | Tüm ekranlar ve ekran modelleri |
| `App` | Yalnız bootstrap: kalıcılık kabını kurar, `AppRootView`'a enjekte eder |

**Katman kuralı:** `Domain` SwiftData/SwiftUI/UIKit/PDFKit/Vision import etmez.
`DomainTests/ArchitectureTests` kaynak taramasıyla doğrular.

**Neden `Features` ayrı paket:** App hedefinde test target yok, ekran snapshot'ları
zorunluydu.

---

## 3. Tamamlanan fazlar

| Faz | Çıktı | Commit |
|---|---|---|
| 0 | Proje iskeleti, tasarım tokenları, font bundle, snapshot altyapısı, `verify-offline.sh` | `c8809a5` |
| 1 | SwiftData modelleri, Repository protokolleri, bellek içi gerçeklemeler | `c62b4b6` |
| 2 | DesignSystem bileşenleri + 26 snapshot referansı | `0dcd0e1` |
| 3 | Dashboard, işlem listesi, filtre/arama, manuel giriş | `ec3d6cb` |
| 4 | İçe aktarma hattı, parser'lar, onay akışı, hata dalları | `6987200` |
| 5 | Bütçeler, `BudgetEngine`, yerel bildirim | `22d8fe5`, `d027edf` |
| 6 | Raporlar (Swift Charts), dönem karşılaştırma | `f761958` |
| 7 | Onboarding, kilit, ayarlar, şifreli yedek | `f6b6fba` |
| 8 | Yayın altyapısı: xcconfig, gizlilik manifesti, sürümleme, ihracat analizi, açılış ekranı, Release yapılandırması, arşivleme | `2ca0963`…`b06ced2` |
| 9.1 | Hesap yönetimi, içe aktarmada hedef hesap seçimi | `7eec11a` |
| 9.2 | Kaydedilebilir sütun eşlemesi, ayrıştırma raporu, anonim örnek paylaşımı | `fbd9f15` |
| 9.3 | Örnek veri modu, B1 illüstrasyonu, kategori simge eşlemesi | `036eee5`, `bb2cca0` |
| 9.4 | Geri bildirim yolu, anonim hata sayacı | `feb1156` |
| 10.1 | Erişilebilirlik: tutar okunuşu, ekran etiketleri, grafik özeti, XXXL yerleşim | `b4db490` |
| 10.2 | Performans: 10.000 işlemlik ölçüm, store tarafı arama, sayfalama, toplam önbelleği | `816fb5b` |
| 10.3 | Dayanıklılık: iki aşamalı içe aktarma, açılışta onarım, yedek uçtan uca | `7441d53` |
| 11 | App Store Connect paketi: mağaza metinleri, gizlilik politikası, destek sayfası, ekran görüntüleri, arşiv | — |

**Ekranlar (tasarım dosyasındaki kodlarla):** A1–A3 onboarding, A4 kilit,
B1 boş durum, B2 iskelet, C1–C8 içe aktarma ve hata dalları, D1 dashboard,
D2 işlem listesi, D3 jestler, D4 filtre, D5 detay, D6 filtre boş,
E1 bütçeler, E2 bütçe editörü, E3 raporlar, E4 manuel giriş,
F1 ayarlar, F2 mahremiyet raporu, F3 tüm verileri sil.

---

## 4. Test durumu

245 test geçiyor. `./Scripts/test-all.sh` hepsini koşar.

| Paket | Test |
|---|---|
| Core | 30 — biçimlendirme, kuruş aritmetiği, hash, şifreleme, gizlilik manifesti |
| Domain | 51 — varlık değişmezleri, filtre, bütçe eşikleri, raporlar, katman kuralı, örnek defter |
| Persistence | 32 — CRUD, sorgu eşdeğerliği, CloudKit kapalı, dosya koruma, yedek, 10.000 işlemde performans |
| ImportPipeline | 32 — golden parser testleri, hat akışı, hata dalları, rapor, anonimleştirme |
| DesignSystem | 26 — 17 kontrast oranı, font çözümleme, düzen kuralı, snapshot |
| Features | 74 — ekran modelleri, hesap yönetimi, eşleme, sürüm, snapshot, örnek veri, kategori simgeleri, geri bildirim ve hata sayacı, dayanıklılık |

**Doğrulama araçları:**
- `Scripts/verify-offline.sh` — kaynak ağacında ağ izi arar, bulursa build'i düşürür.
  Kelimeyi değil kullanımı arar (`CloudKit` bir test adında geçebilir,
  `import CloudKit` geçemez). Negatif test edildi. Pre-commit hook'una bağlı.
- `Scripts/test-all.sh` — paket paket test koşar.
- `Scripts/subset-fonts.sh` — fontları Türkçe kapsamına indirger (1,16 MB → 336 KB).
- `Scripts/make-app-icon.swift` — uygulama ikonunu üretir (alfasız).
- `Scripts/make-launch-mark.swift` — açılış ekranı işaretini üretir.
- `Scripts/verify-privacy-manifest.sh` — gizlilik manifestini kaynakta ve pakette denetler.
- `Scripts/verify-app-icon.sh` — ikon boyutu ve alfa kanalı denetimi.
- `Scripts/bump-build.sh` — build numarasını artırır, commit atmaz.
- `Scripts/archive.sh` — dört kapıdan (çevrimdışılık, manifest, ikon, testler) geçmeden
  arşiv üretmez. Team ID gerektirir.

**Snapshot altyapısı elde yazıldı** (üçüncü parti paket yasak): `UIHostingController`
+ `UIWindow` trait override + `layer.render` + PNG karşılaştırma. Dört varyant:
açık/koyu × standart/XXL. Referans yoksa ilk koşu yazar ve düşer, ikinci koşu karşılaştırır.

---

## 5. Verilen kararlar ve gerekçeleri

Bunlar tasarım dosyasıyla çelişen ya da dosyada belirtilmemiş noktalarda alındı.
Cowork bunları değiştirmeyi önerirse gerekçeyi bilerek önermeli.

**Tasarım dosyasındaki hatalar düzeltildi:**
- `TypeFace.data = "IBMPlexMono"` CoreText'te çözülmüyor (aile adı "IBM Plex Mono").
  Aile adı kullanıldı; çözülmezse sessizce sistem fontuna düşüyordu.
- Font tokenları `Font.sd.*` ad alanına alındı: `caption` SwiftUI'ın kendi
  `Font.caption`'ı ile çakışıp her çağrı yerinde derlemeyi düşürüyordu.
- `balance.hero` puntosu kendi tablosundan geliyor: `relativeTo: .largeTitle`
  `.accessibility2`'de 44 pt'ı ~98 pt yapıyordu, tasarım 56 pt sınırı istiyor.
- `TransactionRow` düzen eşiği `ViewThatFits` yerine
  `dynamicTypeSize.isAccessibilitySize`: ViewThatFits adayları sarmasız genişlikte
  ölçtüğü için dar kartlarda standart kademede bile dikey adayı seçiyordu.

**Türkçe metin işleme:**
- Mükerrer hash'te Türkçe harfler ASCII'ye katlanıyor. Ekstre "MIGROS ATASEHIR",
  elle giriş "Migros Ataşehir" yazıyor; katlama olmadan tr_TR büyük harf kuralı
  ikisini ayırıp mükerreri kaçırıyordu.
- İşyeri adında locale girdiye göre seçiliyor: `capitalized(with: tr_TR)`
  ASCII "MIGROS"u "Mıgros" yapıyordu. Türkçeye özgü harf taşımayan metin `en_US` ile.

**Finansal mantık:**
- Tutar daima pozitif saklanır, yön ayrı alanda. Tasarım gelir/gider ayrımını
  işaret + ikon + renk üçlüsüyle kodluyor; işaretin tutara gömülmesi bu üçlüyü kırardı.
- Transfer net varlığı değiştirmez ama iki hesabı ters yönde etkiler.
- Yönsüz tutarda (bakiye) işaret değerin kendisinden gelir; eksi bakiye mutlak
  değerle gösterilince yanlış rakam çıkıyordu (simülatörde yakalandı).
- Bütçeyi yalnızca gider tüketir. Günlük harcanabilir pay aşımda gösterilmez.
- Dönem karşılaştırması orana göre değil tutara göre sıralanır: küçük kalemlerdeki
  büyük yüzdeler listeyi ele geçirmemeli. Önceki dönem sıfırsa "yeni" yazılır.

**Güvenlik:**
- Yedek anahtarı iki aşamalı: PBKDF2-HMAC-SHA256 (600.000 tur) ile parola germe,
  sonra HKDF-SHA256. Kullanıcı yalnız HKDF istemişti; HKDF hızlıdır ve yedek dosyası
  ele geçtiğinde zayıf parolayı yavaşlatmaz. Tur sayısı dosya başlığında saklanıyor.
- Şifreleme AES-GCM. Kurcalanan dosya ile yanlış parola aynı hatayı verir.
- Geri yükleme yıkıcı: arşiv defterin yerine geçer, birleştirme yapılmaz.
- Bildirim gövdesinde tutar yazılmaz — kilit ekranı bakiye sızdırmamalı.
- Arşiv JSON'unda ISO8601 kullanılmıyor: alt saniyeyi atıyor ve geri yüklenen kayıt
  kaynağıyla eşleşmiyordu.

**Örnek veri (Faz 9.3):**
- Örnek defter üretim kodunda durur, `#if DEBUG` ile ayrılmaz: TestFlight test
  kullanıcısı da görecek. Ayırt edilebilirlik koşullu derlemeyle değil kimlikle:
  her kayıt sabit bir ImportBatch'e bağlı (`SampleLedger.batchID`), temizleme
  yalnızca o kimliğe bakar.
- Örnek işlemler kullanıcının hesabına değil ayrı bir "Örnek Banka" hesabına
  yazılır; temizleme sonrası gerçek hesabın bakiyesi hiç oynamamış olur.
- Seçim onboarding'in son sayfasında anahtar (buton değil): iki bitiş yolu da
  (Face ID aç / şimdi değil) aynı anahtarı okur, yoksa Face ID'yi açan kullanıcı
  örnek veriyi hiç göremiyordu.

**Geri bildirim (Faz 9.4):**
- Rapora defterden yalnızca **sayı** çıkar: işlem/hesap/bütçe adedi ve hata
  sayacı. İşlem detayı, tutar, işyeri adı, hesap adı, dosya adı ve hata metni
  girmez — kullanıcı raporu tanımadığı birine gönderiyor olabilir.
- Hata sayacı hata **metnini** saklamaz; açıklamalar dosya ya da işyeri adı
  taşıyabiliyor. Yalnızca üç sayaç: veri okuma, içe aktarma, yedekleme.
- Zayıf parola gibi kullanıcı hataları sayaca girmez; sayaç uygulamanın
  hatasını ölçüyor.
- "Tüm verileri sil" sayacı da sıfırlar: silinen defterin hataları geri
  bildirimde görünmemeli.
- Gönderim `ShareLink` ile sistem paylaşım sayfasından; uygulama hiçbir yere
  bağlanmaz. Paylaşılacak metnin tamamı gönderimden önce ekranda.

**Erişilebilirlik (Faz 10.1):**
- Okunan dize ekrandaki dizeden ayrı: "₺ 842,60" seslendirmede para gibi
  duyulmuyor. `Fmt.spoken` "eksi 842 lira 60 kuruş" üretiyor.
- Kuruş sıfırsa okunmuyor; liste taramasında her satırda "sıfır kuruş" duymak
  yoruyor.
- Yön sözcüğü ("gider") etikete yazılmıyor: işaretin karşılığı zaten okunuyor.
- Kartlar tek erişilebilirlik öğesi (bakiye, bütçe, dağılım satırı): parçalar
  ayrı okununca aralarındaki ilişki kayboluyordu.
- Grafik tek öğe, değeri sözlü özet. Çubukları tek tek dinlemek eğilimi
  anlatmıyor.
- Erişilebilirlik kademelerinde yan yana tutarlar alt alta geçiyor
  (`AdaptiveStack`); eşik `ViewThatFits` değil `dynamicTypeSize.isAccessibilitySize`
  — gerekçe `TransactionRow` ile aynı.
- Ayrıntı ve açık kalanlar: `docs/A11Y-AUDIT.md`.

**Performans (Faz 10.2):**
- Arama store tarafında, işlem satırındaki `searchIndex` sütununda. Kural
  `TransactionEntity.searchIndexText` içinde tek yerde; bellekteki yol da onu
  kullanıyor, iki yol aynı sonucu veriyor.
- Sütun sonradan eklendiği için eski kayıtlarda NULL kalıyor: yüklemle süzmek
  onları görmüyor. Geri doldurma satırları okuyup karşılaştırıyor ve açılışta
  bir kez çalışıyor (`searchIndex.backfilled.v1`).
- İşlem listesi 200'er satır. Sınır yalnız başka filtre kalmadığında store
  tarafında uygulanır; yoksa elenecek satırlar sınırı doldurup sonucu eksiltir.
- Net varlık hesap toplamlarından. Toplam actor içinde tutuluyor, her işlem
  yazımı düşürüyor. İlk hesap 10.000 kayıtta ~460 ms — iOS 17 SwiftData'da
  toplama sorgusu yok; ayrıntı ve seçenekler `docs/PERFORMANCE.md`.

**Dayanıklılık (Faz 10.3):**
- İçe aktarma iki aşamalı yazıyor: parti `isComplete = false` ile açılır, işlemler
  yazılır, parti tamamlanır. Uygulama arada ölürse yarım kalan iş küçük parti
  tablosundan saptanıyor; işlemleri taramak 10.000 kayıtta yarım saniye sürerdi.
- Açılıştaki onarım işlem **silmiyor**: satır yazmış yarım parti gerçek sayısıyla
  tamamlanıyor, hiç yazmamış parti kaydı siliniyor. Kullanıcının verisini silmek
  geri alınamaz bir karar olurdu.
- `isComplete` alanı yedek arşivine de giriyor; alanı olmayan eski yedeklerde
  tamamlanmış sayılıyor, yoksa geçmiş içe aktarmalar yarım görünürdü.
- Ayrıntı ve sınanmayanlar: `docs/RESILIENCE.md`.

**App Store paketi (Faz 11):**
- Uygulama **ücretsiz** çıkıyor, sonraki sürümlerde uygulama içi satın alma
  düşünülüyor. **Reklam eklenmeyecek:** reklam SDK'sı ağ katmanı ve üçüncü parti
  bağımlılık kısıtlarını kırar, "Data Not Collected" etiketini ve mağaza metnini
  yalanlar. Ayrıntı `docs/APPSTORE.md` bölüm 12.1.
- App Privacy cevabı **Data Not Collected**; gerekçe ve manifestle satır satır
  eşleme `docs/APPSTORE.md` bölüm 8. Geri bildirim ve yedek akışları "toplama"
  sayılmıyor çünkü veri geliştiricinin erişebileceği hiçbir yere gitmiyor.
- App Review'a eklenecek örnek ekstre **kurgusal bir bankaya** ait
  (`Scripts/make-sample-statement.swift`). Gerçek bir bankanın adına düzenlenmiş
  sahte finansal belge üretilmedi; bedeli, reviewer'ın otomatik tanıma yerine
  elle sütun eşleme akışını görmesi.
- Ekran görüntülerinde **kısa başlık bandı** var, cihaz çerçevesi yok; veri
  örnek defterden geliyor, gerçek kayıt kullanılmıyor (`docs/SCREENSHOTS.md`).
- Ekran görüntüleri ve arşiv `build/` altında, gitignore'lu: ikili çıktı depoya
  girmiyor, üretimi betiklerden tekrarlanıyor.

**Ürün kararları:**
- Varsayılan kategoriler: 13 gider (tasarımdaki 12 + "Yeme-içme") + 3 gelir
  (Maaş, Serbest çalışma, Diğer gelir). "Yeme-içme" renk yuvasını Bağış ile paylaşır.
- İlk açılışta "Nakit" hesabı yazılır: hesapsız manuel giriş yapılamıyor.
- Kart köşesi 16 pt (tasarım kararları bölümü normatif alındı; ekran çizimlerinde 18px).
- Dashboard yalnızca dikkat isteyen bütçeleri gösterir (uyarı ve aşım), en fazla iki.

---

## 6. Bilinen eksikler

### Yayını bloklayan
1. ~~**Team ID yok.**~~ 2026-08-16'da geldi: `Config/Local.xcconfig` içinde
   `TEAM_ID = 27Q876RTFC`, derleme ayarlarında `DEVELOPMENT_TEAM` olarak görünüyor.
   Dosya gitignore'lu, repoya girmez. `Scripts/archive.sh` TEAM_ID kapısını geçer;
   arşiv henüz üretilmedi.
2. **Bundle ID kaydı yapılmadı** — `com.sessizdefter.app` Apple'da kaydedilecek.
3. ~~**App Store metadata yok.**~~ Yazıldı (Faz 11): `docs/APPSTORE.md`,
   `docs/PRIVACY-POLICY.md`, `docs/SUPPORT.md`, `docs/SCREENSHOTS.md`.
   Karakter sınırları `Scripts/verify-appstore-limits.sh` ile denetleniyor.
4. **Destek URL'i ve gizlilik politikası URL'i yayımlanmadı.** Metinler hazır;
   GitHub Pages `main` dalının `/docs` klasöründen açılacak (kullanıcı kararı,
   2026-08-17). Sayfa yayına girmeden App Store Connect kaydı tamamlanamaz.
5. **İhracat beyanı onay bekliyor.** `docs/EXPORT-COMPLIANCE.md` analizi yazıldı,
   `ITSAppUsesNonExemptEncryption = false` bırakıldı, kullanıcı onayı alınmadı.
6. ~~**Guideline 2.1 riski:**~~ B1 illüstrasyonu çizildi (Faz 9.3,
   `DesignSystem/Components/LedgerBoxArtwork.swift`); kaynak ağacında yer tutucu
   metni kalmadı.

### Ürün eksiği
7. **Parser gerçek ekstre ile doğrulanmadı.** Fixture metinleri sentetik. Faz 9.2'de
   manuel sütun eşleme, canlı önizleme, ayrıştırma raporu ve anonim örnek paylaşımı
   eklendi; artık gerçek PDF ile test edilebilir. **Kullanıcıdan gerçek (anonimleştirilmiş)
   Ziraat/Garanti/İş Bankası ekstresi bekleniyor.**
8. **E4 manuel giriş** sistem `Form` + `decimalPad` kullanıyor; tasarım özel tuş
   takımı ve "son kullanılanlar" kategori çipleri gösteriyor.
9. ~~Kategori ikonları yer tutucu.~~ Eşleme yapıldı: `docs/CATEGORY-ICONS.md`,
   tek kaynak `DefaultCategories`, `FeaturesTests/CategoryIconTests` her adı
   `UIImage(systemName:)` ile çözer.
10. ~~B1 boş durum illüstrasyonu yer tutucu.~~ Çizildi (Faz 9.3).
11. ~~Örnek veri modu yok.~~ Eklendi (Faz 9.3): onboarding anahtarı, Ayarlar'da
    tek dokunuşla temizleme.
12. ~~Geri bildirim yolu yok.~~ Eklendi (Faz 9.4): Ayarlar > Geri bildirim
    gönder, anonim hata sayacı, `ShareLink`.
13. **CSV dışa aktarma** F1'de listeleniyor, yazılmadı.
14. **Makbuz fotoğrafı** D5'te listeleniyor, yazılmadı.
15. **Yedek dosya akışı simülatörde uçtan uca denenmedi** (Faz 10.3).

### Kalite
16. ~~Erişilebilirlik denetimi yapılmadı.~~ Yapıldı (Faz 10.1),
    `docs/A11Y-AUDIT.md`. **Kalan:** VoiceOver ile gerçek cihazda uçtan uca
    gezinme; simülatörde betikle sürülemedi.
17. ~~Performans ölçülmedi.~~ Ölçüldü ve düzeltildi (Faz 10.2),
    `docs/PERFORMANCE.md`. Net varlığın ilk hesabı 10.000 kayıtta ~460 ms;
    kullanıcı kararıyla şimdiki hâl kaldı (önbellek + iskelet).
18. **Bellek/sızıntı profillemesi yapılmadı** — Instruments turu bu fazda kapsanmadı.
19. ~~Dayanıklılık senaryoları denenmedi.~~ Denendi (Faz 10.3),
    `docs/RESILIENCE.md`. **Kalan:** gerçek cihazda düşük depolama ve "Tüm
    verileri sil" akışı.

---

## 7. Çalışma şekli

- Her faz kendi commit'i. Conventional Commits, tip İngilizce, açıklama Türkçe.
- Commit gövdesi "ne" değil "neden" yazar.
- Kod yorumları da öyle: kararın gerekçesi, kodun tekrarı değil.
- Her fazın sonunda: ne yapıldı, hangi testler geçti, açık sorular.
- Tasarım dosyalarıyla çelişen ya da eksik bir şey varsa kullanıcıya sorulur,
  kendi kafasına göre doldurulmaz.
- Değişiklikler simülatörde de doğrulanır; yedi gerçek hata yalnızca orada yakalandı:
  tazelenmeyen dashboard, eksi bakiyenin artı görünmesi, yanlış düzen seçimi,
  içe aktarmada hedef hesap, örnek verinin kategorisiz gelmesi (kategoriler
  onboarding'de henüz tohumlanmamıştı), dağılım kartının "kalanlar" kovasını
  "Kategorisiz" yazması, örnek veri silinince defterin hesapsız kalması.

## 8. Kaynak

Depo: https://github.com/srkngthb16/sessiz-defter
Tasarım dosyaları `design/` altında (üç `.dc.html`): mimari, renk/tipografi sistemi,
mobil ekran panosu. Bunlar spesifikasyondur, ilham değil.
