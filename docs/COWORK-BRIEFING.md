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

**Ekranlar (tasarım dosyasındaki kodlarla):** A1–A3 onboarding, A4 kilit,
B1 boş durum, B2 iskelet, C1–C8 içe aktarma ve hata dalları, D1 dashboard,
D2 işlem listesi, D3 jestler, D4 filtre, D5 detay, D6 filtre boş,
E1 bütçeler, E2 bütçe editörü, E3 raporlar, E4 manuel giriş,
F1 ayarlar, F2 mahremiyet raporu, F3 tüm verileri sil.

---

## 4. Test durumu

184 test geçiyor. `./Scripts/test-all.sh` hepsini koşar.

| Paket | Test |
|---|---|
| Core | 25 — biçimlendirme, kuruş aritmetiği, hash, şifreleme, gizlilik manifesti |
| Domain | 41 — varlık değişmezleri, filtre, bütçe eşikleri, raporlar, katman kuralı |
| Persistence | 20 — CRUD, sorgu eşdeğerliği, CloudKit kapalı, dosya koruma, yedek |
| ImportPipeline | 32 — golden parser testleri, hat akışı, hata dalları, rapor, anonimleştirme |
| DesignSystem | 21 — 17 kontrast oranı, font çözümleme, düzen kuralı, snapshot |
| Features | 45 — ekran modelleri, hesap yönetimi, eşleme, sürüm, snapshot |

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

**Ürün kararları:**
- Varsayılan kategoriler: 13 gider (tasarımdaki 12 + "Yeme-içme") + 3 gelir
  (Maaş, Serbest çalışma, Diğer gelir). "Yeme-içme" renk yuvasını Bağış ile paylaşır.
- İlk açılışta "Nakit" hesabı yazılır: hesapsız manuel giriş yapılamıyor.
- Kart köşesi 16 pt (tasarım kararları bölümü normatif alındı; ekran çizimlerinde 18px).
- Dashboard yalnızca dikkat isteyen bütçeleri gösterir (uyarı ve aşım), en fazla iki.

---

## 6. Bilinen eksikler

### Yayını bloklayan
1. **Team ID yok.** Apple Developer üyeliği ödendi, onay bekleniyor (48 saate kadar).
   Onay gelince `cp Config/Local.xcconfig.example Config/Local.xcconfig` ve Team ID yazılır.
   `Scripts/archive.sh` bunsuz çalışmaz.
2. **Bundle ID kaydı yapılmadı** — `com.sessizdefter.app` Apple'da kaydedilecek.
3. **App Store metadata yok** — Faz 11'de üretilecek.
4. **Destek URL'i ve gizlilik politikası URL'i yok.** App Store Connect'te zorunlu alanlar;
   yayınlanmış bir sayfa gerekiyor (GitHub Pages yeterli).
5. **İhracat beyanı onay bekliyor.** `docs/EXPORT-COMPLIANCE.md` analizi yazıldı,
   `ITSAppUsesNonExemptEncryption = false` bırakıldı, kullanıcı onayı alınmadı.
6. **Guideline 2.1 riski:** B1 boş durumunda ekranda "Yer tutucu · ilk açılış görseli"
   yazıyor. Harici TestFlight testinden önce gitmeli.

### Ürün eksiği
7. **Parser gerçek ekstre ile doğrulanmadı.** Fixture metinleri sentetik. Faz 9.2'de
   manuel sütun eşleme, canlı önizleme, ayrıştırma raporu ve anonim örnek paylaşımı
   eklendi; artık gerçek PDF ile test edilebilir. **Kullanıcıdan gerçek (anonimleştirilmiş)
   Ziraat/Garanti/İş Bankası ekstresi bekleniyor.**
8. **E4 manuel giriş** sistem `Form` + `decimalPad` kullanıyor; tasarım özel tuş
   takımı ve "son kullanılanlar" kategori çipleri gösteriyor.
9. **Kategori ikonları yer tutucu.** SF Symbols eşlemesi yapılmadı (Faz 9.3).
10. **B1 boş durum illüstrasyonu** kesikli çerçeveli yer tutucu (Faz 9.3).
11. **Örnek veri modu yok** — test kullanıcısı boş ekranla karşılaşıyor (Faz 9.3).
12. **Geri bildirim yolu yok** (Faz 9.4).
13. **CSV dışa aktarma** F1'de listeleniyor, yazılmadı.
14. **Makbuz fotoğrafı** D5'te listeleniyor, yazılmadı.
15. **Yedek dosya akışı simülatörde uçtan uca denenmedi** (Faz 10.3).

### Kalite
16. Erişilebilirlik denetimi yapılmadı (Faz 10.1).
17. Performans ölçülmedi — 10k işlemlik defter testi yok (Faz 10.2).
18. Bellek/sızıntı profillemesi yapılmadı (Faz 10.2).
19. Dayanıklılık senaryoları denenmedi: uçak modu, düşük depolama, içe aktarma
    sırasında uygulamayı öldürme, yarım kalan ImportBatch (Faz 10.3).

---

## 7. Çalışma şekli

- Her faz kendi commit'i. Conventional Commits, tip İngilizce, açıklama Türkçe.
- Commit gövdesi "ne" değil "neden" yazar.
- Kod yorumları da öyle: kararın gerekçesi, kodun tekrarı değil.
- Her fazın sonunda: ne yapıldı, hangi testler geçti, açık sorular.
- Tasarım dosyalarıyla çelişen ya da eksik bir şey varsa kullanıcıya sorulur,
  kendi kafasına göre doldurulmaz.
- Değişiklikler simülatörde de doğrulanır; üç gerçek hata yalnızca orada yakalandı
  (tazelenmeyen dashboard, eksi bakiyenin artı görünmesi, yanlış düzen seçimi).

## 8. Kaynak

Depo: https://github.com/srkngthb16/sessiz-defter
Tasarım dosyaları `design/` altında (üç `.dc.html`): mimari, renk/tipografi sistemi,
mobil ekran panosu. Bunlar spesifikasyondur, ilham değil.
