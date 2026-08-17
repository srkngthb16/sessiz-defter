# App Store Connect Paketi

Sürüm 1.0.0 için App Store Connect'e girilecek her alanın metni. Alan adları
İngilizce (App Store Connect'te öyle görünüyor), içerik Türkçe.

**Durum:** taslak. Aşağıdaki üç kutu kullanıcı onayı bekliyor:
bundle ID kaydı, destek/gizlilik URL'leri, ihracat beyanı
(`docs/EXPORT-COMPLIANCE.md` bölüm 4).

Karakter sayıları `Scripts/verify-appstore-limits.sh` ile denetleniyor; metni
değiştirirsen betiği koştur.

---

## 1. Uygulama kimliği

| Alan | Değer | Kaynak |
|---|---|---|
| Bundle ID | `com.sessizdefter.app` | `Config/Shared.xcconfig` |
| SKU | `sessizdefter-ios-1` | serbest; App Store Connect'te bir kez girilir |
| Primary Language | Türkçe (Turkish) | `CFBundleDevelopmentRegion = tr` |
| Version | `1.0.0` | `MARKETING_VERSION` |
| Build | `2` | `CURRENT_PROJECT_VERSION`, `Scripts/bump-build.sh` artırır |
| Platform | iOS 17.0+, yalnız iPhone | `IPHONEOS_DEPLOYMENT_TARGET`, `TARGETED_DEVICE_FAMILY = 1` |
| Yönlendirme | Yalnız dikey | `UISupportedInterfaceOrientations` |

**Bundle ID kaydedildi** (2026-08-17): developer.apple.com > Identifiers,
Explicit App ID `com.sessizdefter.app`, hiçbir capability işaretlenmedi —
uygulamanın push, App Groups, iCloud ya da Sign in with Apple ihtiyacı yok.

### 1.1 Arşiv nasıl imzalanıyor

`./Scripts/archive.sh` dört kapıdan geçtikten sonra arşivi **imzasız** üretiyor;
dağıtım imzası export adımında biniyor. Üç deneme sonunda bu yola girildi:

| Deneme | Hata |
|---|---|
| Düz `archive.sh` | `No profiles for 'com.sessizdefter.app' were found` |
| `-allowProvisioningUpdates` | `No Accounts: Add a new account in Accounts settings.` — Xcode'da hesap yoktu |
| Hesap eklendikten sonra | `Your team has no devices from which to generate a provisioning profile` |

Üçüncünün nedeni: otomatik imzalamada arşiv adımı "iOS App Development" profili
istiyor, o profil de takımda kayıtlı en az bir cihaz olmasını şart koşuyor.
Mağazaya giden yapının geliştirme profiliyle işi yok — export zaten
`app-store-connect` yöntemiyle dağıtım profilini üretip ikiliyi yeniden
imzalıyor. Arşivi imzasız üretmek cihaz kaydı ihtiyacını tümden kaldırdı.

**Sonuç (2026-08-17):** `build/export/SessizDefter.ipa`, sürüm 1.0.0 (2), profil
`iOS Team Store Provisioning Profile: com.sessizdefter.app`,
`get-task-allow = false`.

İlk koşuda sertifika ya da profil üretilmesi gerekiyorsa:

```bash
SD_ALLOW_PROVISIONING=1 ./Scripts/archive.sh
```

Bayrak varsayılan kapalı: Apple hesabında sertifika ve profil yaratmak kalıcı
bir iş, arşiv betiğinin sessizce yapacağı şey değil.

---

## 2. Ad, alt başlık, tanıtım metni

### App Name (en fazla 30 karakter)

```
Sessiz Defter
```

13 karakter. Ad App Store'da benzersiz olmak zorunda; alınmışsa ikinci seçenek
`Sessiz Defter — Finans` (22 karakter). Ada anahtar kelime doldurulmadı:
tire sonrası kelime yığmak ASO'da az kazandırıyor, markayı bulanıklaştırıyor.

### Subtitle (en fazla 30 karakter)

```
Çevrimdışı bütçe ve ekstre
```

26 karakter. Alt başlık ada eklenmiş bir slogan değil, arama dizinine giren
ikinci alan: üç anahtar kelimeyi ("çevrimdışı", "bütçe", "ekstre") taşıyor ve
uygulamanın tek ayırt edici özelliğini ilk kelimede söylüyor.

### Promotional Text (en fazla 170 karakter, sürüm çıkarmadan güncellenebilir)

```
Ekstrenizi seçin, gerisini telefon yapsın. Ayrıştırma da kategorileme de cihazda; uygulamanın ağ katmanı hiç yazılmadı. Uçak modunda da aynı çalışır.
```

---

## 3. Keywords (en fazla 100 karakter, virgülle ayrılır, virgülden sonra boşluk yok)

```
harcama,gider,gelir,pdf,banka,hesap,tasarruf,finans,para,takip,kategori,fiş,nakit,rapor,masraf
```

94 karakter.

**Neden bu kelimeler:**
- Ad ve alt başlıktaki kelimeler (`sessiz`, `defter`, `çevrimdışı`, `bütçe`,
  `ekstre`) burada tekrarlanmadı — Apple o iki alanı zaten dizine alıyor,
  tekrar yer israfı.
- Tekil biçimler yazıldı; Apple eşleşmeyi kök üzerinden yapıyor, hem "harcama"
  hem "harcamalar" yazmak yer yiyor.
- Rakip marka adı yok (App Store Review Guideline 5.2.1 ihlali olurdu).
- "kredi kartı", "hesap özeti" gibi iki kelimelik ifadeler yazılmadı: Apple
  alandaki kelimeleri birbiriyle çaprazlayarak eşleştiriyor, boşluk harcamak
  gereksiz.

---

## 4. Description (en fazla 4000 karakter)

```
Sessiz Defter, harcamalarınızı telefonunuzun dışına hiç çıkarmadan takip
etmeniz için yazıldı.

Bankanızın PDF ekstresini Dosyalar'dan seçersiniz. Metin çıkarma, banka
formatını tanıma ve işlemleri kategorileme tamamen bu telefonun işlemcisinde
yapılır. Sonuç onay ekranına gelir; hiçbir satır siz görmeden deftere yazılmaz.

NEDEN "SESSİZ"

Uygulamanın ağ katmanı hiç yazılmadı. Bu, kapatılabilir bir ayar değil,
olmayan bir özellik. Sunucu yok, hesap yok, e-posta yok, senkronizasyon yok,
analitik yok, çökme raporu yok, reklam kimliği okunmuyor. Uçak modunda
uygulamanın tamamı çalışır.

Ayarlar > Mahremiyet raporu sayfası hangi iznin kullanıldığını ve
kullanılmadığını tek ekranda gösterir.

NE YAPAR

• Ekstre içe aktarma — PDF'ten işlemleri çıkarır, mükerrer kayıtları tanır,
düşük güvenli satırları işaretler. Banka formatı tanınmazsa sütunları elle
eşlersiniz; eşleme kaydedilir, ikinci ekstrede tekrar sorulmaz.

• Otomatik kategorileme — 13 gider ve 3 gelir kategorisi. Kendi kurallarınızı
yazabilir, kategori adlarını ve simgelerini değiştirebilirsiniz.

• Bütçeler — aylık limit, kalan gün başına harcanabilir pay, uyarı ve aşım
eşiklerinde yerel bildirim. Bildirim gövdesinde tutar yazmaz; kilit ekranı
bakiyenizi sızdırmaz.

• Raporlar — kategori dağılımı, aylık eğilim, dönem karşılaştırması.

• Manuel giriş — bankanız desteklenmiyorsa ya da nakit harcadıysanız işlemi
elle eklersiniz. Hesaplar arası transfer net varlığı değiştirmez.

• Şifreli yedek — kendi belirlediğiniz parolayla AES-256-GCM ile şifrelenmiş
tek dosya. Dosyayı nereye koyacağınıza siz karar verirsiniz.

• Face ID kilidi — hesap açmanız gerekmez; kilit cihazda doğrulanır, yedek
olarak iPhone parolanız kullanılır.

TÜRKÇE İÇİN YAZILDI

Tutarlar ₺ ve virgüllü kuruşla, tarihler gün.ay.yıl. Ekstredeki "MIGROS
ATASEHIR" ile elle yazdığınız "Migros Ataşehir" aynı işlem sayılır — Türkçe
harf katlaması mükerrer tespitine gömülü.

ERİŞİLEBİLİRLİK

Tutarlar VoiceOver'da "eksi 842 lira 60 kuruş" diye okunur, rakam rakam değil.
Grafikler sözlü özet taşır. En büyük yazı boyutlarında tutarlar kırpılmaz,
yerleşim alt alta geçer.

NE YAPMAZ

• Bankanıza bağlanmaz. Banka şifrenizi, kart numaranızı ya da kimlik
bilgilerinizi hiçbir yerde istemez.

• Reklam göstermez, abonelik satmaz, uygulama içi satın alma içermez.

• Ekstrenizin kopyasını saklamaz — PDF okunur, işlemler çıkarılır, dosya
bırakılır.

İlk açılışta "örnek defterle gez" seçeneği var: kendi verinizi girmeden önce
uygulamanın dolu halini görebilirsiniz. Örnek veri Ayarlar'dan tek dokunuşla
silinir ve kendi kayıtlarınıza dokunmaz.
```

---

## 5. What's New in This Version

İlk sürümde App Store Connect bu alanı zorunlu tutmaz. Yine de doldurulacaksa:

```
İlk sürüm.

Bankanızın PDF ekstresini cihazda ayrıştırır, işlemleri kategoriler, bütçe ve
rapor üretir. Ağ katmanı yok: veri telefondan çıkmaz.
```

Sonraki sürümlerde bu alan "ne değişti"yi yazar, özellik listesini tekrarlamaz.

---

## 6. Kategori

| Alan | Değer |
|---|---|
| Primary Category | **Finance** |
| Secondary Category | *(boş bırakılıyor)* |

**Neden ikincil kategori yok:** İkincil kategori yalnızca ilgili listelerde
görünürlük katıyor; "Productivity" bu uygulamayı bütçe uygulamalarının değil
görev yöneticilerinin yanına koyar. Yanlış listede görünmek indirmeden çok
kaldırma getiriyor. Değiştirilmesi kolay bir alan — yayından sonra ölçüp
gözden geçirilebilir.

**Finance kategorisinin getirdiği ek denetim:** Guideline 1.4.1 ve 5.2.1
finansal uygulamalarda "banka ile ilişkili görünme"yi yasaklıyor. Uygulama
hiçbir bankanın markasını, logosunu ya da renk kimliğini kullanmıyor; banka
adları yalnızca "hangi ekstre formatı tanındı" bilgisi olarak geçiyor. Ekran
görüntülerinde de banka logosu yok (`docs/SCREENSHOTS.md`).

---

## 7. Age Rating (yaş sınırı anketi)

Hedef: **4+**. Anketin tüm içerik sorularına cevap **None / No**.

| Soru başlığı | Cevap | Dayanak |
|---|---|---|
| Cartoon or Fantasy Violence | None | İçerik yok |
| Realistic Violence | None | İçerik yok |
| Sexual Content or Nudity | None | İçerik yok |
| Profanity or Crude Humor | None | Metinler kullanıcının kendi kayıtları |
| Alcohol, Tobacco, or Drug Use | None | İçerik yok |
| Mature/Suggestive Themes | None | İçerik yok |
| Horror/Fear Themes | None | İçerik yok |
| Medical/Treatment Information | None | İçerik yok |
| **Gambling** | **No** | Kumar yok. Kategori Finance ama uygulama bahis, kripto alım satımı ya da yatırım tavsiyesi içermiyor |
| Contests | No | Yok |
| Unrestricted Web Access | **No** | Tarayıcı yok, `WKWebView` yok, ağ katmanı yok |
| Kullanıcı üretimi içerik / sosyal özellik | **No** | Kullanıcılar arası içerik paylaşımı yok |
| Messaging | No | Yok |
| Kids Category | **Hayır** | Finance kategorisi; hedef kitle çocuk değil |
| In-app purchases | **No** | Satın alma yok |
| Advertising (reklam gösterimi) | **No** | Reklam SDK'sı yok |

**"Made for Kids" işaretlenmiyor.** 4+ derecesi ile Kids kategorisi ayrı
şeyler; Kids kategorisi ek gizlilik yükümlülüğü getiriyor.

**Dikkat:** Apple yaş sınırı anketini 2025'te yeniden düzenledi (13+/16+/18+
kademeleri ve yeni sorular eklendi). Ankette burada listelenmeyen bir soruyla
karşılaşırsan cevabı uydurma — soruyu bu dosyaya ekle, gerekçeyi birlikte
yazalım.

---

## 8. App Privacy formu

Cevap tek satır: **Data Not Collected.**

App Store Connect akışı: *App Privacy > Data Collection > "Do you or your
third-party partners collect data from this app?"* → **No**. Bu cevap
verildiğinde başka soru sorulmuyor ve mağaza sayfasında "Veri Toplanmıyor"
etiketi çıkıyor.

### 8.1 Manifestle satır satır eşleme

`App/PrivacyInfo.xcprivacy` içindeki her anahtarın formdaki karşılığı:

| Manifest anahtarı | Manifest değeri | App Privacy formundaki karşılığı | Tutarlı mı |
|---|---|---|---|
| `NSPrivacyTracking` | `false` | "Data Used to Track You" bölümü hiç açılmıyor | evet |
| `NSPrivacyTrackingDomains` | boş dizi | İzleme alan adı yok; ATT istemi de yok | evet |
| `NSPrivacyCollectedDataTypes` | boş dizi | **Data Not Collected** | evet |
| `NSPrivacyAccessedAPITypes` → `NSPrivacyAccessedAPICategoryUserDefaults`, sebep `CA92.1` | Kilit tercihi, arka planda gizleme, otomatik kilit süresi, tema, onboarding bayrağı | **Formda karşılığı yok.** Bu bölüm "required reason API" beyanı, veri toplama beyanı değil; ikili yüklenirken ayrıca denetleniyor | evet (ayrı mekanizma) |

`CA92.1` sebep kodunun anlamı: "yalnızca uygulamanın kendisinin erişebildiği
UserDefaults verisi". Uygulamanın App Group'u ve uzantısı yok, dolayısıyla
yazılan ayarları başka bir ikili okuyamıyor — kod doğru.

Manifestte **bulunmayan** kategoriler de bilinçli: dosya zaman damgası
(yalnız test kodunda kullanılıyor), disk alanı, sistem açılma zamanı ve aktif
klavyeler API'lerine üretim kodunda hiç dokunulmuyor.

### 8.2 "Toplamıyor" iddiası neye dayanıyor

Form cevabı iddia değil, denetlenen bir durum:

| İddia | Denetleyen |
|---|---|
| Ağ katmanı yok | `Scripts/verify-offline.sh` — kaynak ağacında ağ kullanımı arar, bulursa derlemeyi düşürür. Pre-commit hook'una ve `archive.sh` kapısına bağlı |
| Üçüncü parti SDK yok | Paket bağımlılığı yalnız Apple framework'leri (`docs/COWORK-BRIEFING.md` bölüm 1) |
| CloudKit senkronizasyonu kapalı | `cloudKitDatabase: .none`, `PersistenceTests` doğruluyor |
| Manifest ikilide duruyor | `Scripts/verify-privacy-manifest.sh` — hem kaynakta hem paketlenmiş üründe denetler, `archive.sh` kapısı |
| Manifest içeriği beklendiği gibi | `CoreTests` içindeki gizlilik manifesti testi |

### 8.3 Sınırdaki iki akış — neden yine de "toplanmıyor"

**Geri bildirim ekranı (Ayarlar > Geri bildirim gönder).** Uygulama hiçbir yere
bağlanmaz; metni sistem paylaşım sayfasına verir, alıcıyı kullanıcı seçer.
Metnin tamamı gönderilmeden önce ekranda durur. İçinde tutar, işyeri adı,
hesap adı, dosya adı ya da hata metni yoktur — yalnızca sürüm, cihaz model
kodu, iOS sürümü, kayıt **sayıları** ve üç hata sayacı (`FeedbackReport`,
yasaklı sözcük testiyle denetleniyor). Geliştirici bir kopya almıyor; kullanıcı
isterse kendisi gönderiyor. Apple'ın tanımında "collect" veriyi cihazdan
çıkarıp geliştiricinin erişebileceği yere taşımak demek — burada öyle bir
taşıma yok.

**Şifreli yedek dosyası.** Kullanıcının kendi eylemiyle üretiliyor, kullanıcının
seçtiği konuma yazılıyor, yalnızca kullanıcının parolasıyla açılıyor.
Geliştiriciye giden bir kopya yok.

**Sonuç:** İki akış da veriyi kullanıcının kendi elinde bırakıyor. "Data Not
Collected" doğru cevap. İleride bir destek e-posta adresi yayımlanır ve
kullanıcılar geri bildirim metnini oraya gönderirse bu App Store'un
"uygulama içi toplama" tanımına girmez; yine de gizlilik politikasında
anlatılıyor (`docs/PRIVACY-POLICY.md` bölüm 5).

---

## 9. App Review Information

**Sign-in required:** No. Uygulamada hesap, giriş ve e-posta yok.

**Contact:** *(kullanıcı doldurur — ad, soyad, telefon, e-posta)*

**Notes (İngilizce, App Review Türkçe okumuyor):**

```
The app is fully offline. There is no networking layer at all: no server, no
account, no sync, no analytics, no third-party SDK. It works in airplane mode,
which is the easiest way to verify the claim.

HOW TO SEE A POPULATED APP
On the last onboarding page, turn on "Örnek defterle gez" (browse with sample
data) before finishing. This writes 20 sample transactions, a sample account
and two budgets, so every screen is populated without importing anything.
Sample data can be removed later from Settings > Veri > "Örnek veriyi temizle".

HOW TO TEST STATEMENT IMPORT
A sample statement PDF is attached to this submission. It is synthetic: it
belongs to a fictional bank ("ÖRNEK BANKASI A.Ş."), is stamped as a sample and
contains no real account data. Save it to the Files app, then in the app:
Dashboard > "Ekstre içe aktar" > pick the PDF. Because the fictional bank has
no built-in format, the app will ask you to map the columns (date, description,
amount) once, show a live preview, and then import. Everything runs on device.
No real bank account or credentials are ever requested.

ENCRYPTION
The app uses AES-256-GCM and PBKDF2 only to encrypt a local backup file with a
password the user chooses, plus SHA-256 for duplicate detection. Nothing is
transmitted. ITSAppUsesNonExemptEncryption is set to false accordingly.

LANGUAGE
The app is Turkish-only. Bank names appear only as detected statement formats;
the app is not affiliated with, and does not claim to be affiliated with, any
bank.
```

**Attachment:** örnek ekstre PDF'i — `Scripts/make-sample-statement.swift`
üretir (`build/ornek-ekstre.pdf`).

Belge kurgusal bir bankaya ait ("ÖRNEK BANKASI A.Ş.") ve üstünde "ÖRNEK BELGE"
damgası var. Gerçek bir bankanın adını taşıyan sahte ekstre üretilmedi:
gerçek bir kurumun adına düzenlenmiş uydurma finansal belge, uygulamanın
dışında da kullanılabilecek bir şey olurdu. Bunun bedeli, kurgusal bankanın
yerleşik bir format imzası olmaması — reviewer otomatik tanıma yerine elle
sütun eşleme akışını görüyor. Kayıp değil: C serisinin en kırılgan ekranı da
böylece incelenmiş oluyor.

Gerçek (anonimleştirilmiş) ekstre geldiğinde parser doğrulaması da yapılacak
(`docs/COWORK-BRIEFING.md` bölüm 6, madde 7); o zaman review ekini de
otomatik tanınan bir formatla değiştirmek mümkün.

---

## 10. Zorunlu URL'ler — **kullanıcıdan bekleniyor**

| Alan | Zorunlu mu | Durum |
|---|---|---|
| Privacy Policy URL | **Evet** (App Privacy formunu kaydetmek için şart) | Metin hazır: `docs/PRIVACY-POLICY.md`. Yayınlanmış adres yok |
| Support URL | **Evet** | Yok |
| Marketing URL | Hayır | Yok, boş bırakılacak |

Öneri: GitHub Pages. Depo zaten var, ek maliyet yok, statik sayfa yeterli.
İki sayfa gerekiyor: gizlilik politikası ve destek. Destek sayfası bir
e-posta adresi ve "sorun bildirmek için" birkaç satırdan ibaret olabilir —
App Review boş ya da ulaşılamaz destek sayfasını reddediyor.

**Karar (kullanıcı, 2026-08-17):** Depo herkese açık, Pages `docs/` klasöründen
yayınlanacak. `docs/` içindeki devir notu ve denetim raporları zaten görünür
durumda, Pages açmak yeni bir şey sızdırmıyor.

Yapılacak: GitHub deposunda *Settings > Pages > Source: Deploy from a branch,
Branch: main, Folder: /docs*. Ardından adresler:

| Sayfa | Adres |
|---|---|
| Privacy Policy URL | `https://srkngthb16.github.io/sessiz-defter/PRIVACY-POLICY` |
| Support URL | `https://srkngthb16.github.io/sessiz-defter/SUPPORT` |

Destek sayfası `docs/SUPPORT.md` olarak yazıldı; içindeki e-posta adresi
**boş** — App Store Connect'teki destek adresiyle aynı olmalı, o yüzden
kullanıcı dolduracak. Boş bırakılırsa App Review reddediyor.

---

## 11. İhracat beyanı

`ITSAppUsesNonExemptEncryption = false` Info.plist'te duruyor; bu değerle
App Store Connect her yüklemede ihracat sorularını sormuyor.

Analiz ve gerekçe: `docs/EXPORT-COMPLIANCE.md`. **Bölüm 4'teki karar hâlâ
kullanıcı onayı bekliyor.**

---

## 12. Fiyat ve kullanılabilirlik

| Alan | Değer | Gerekçe |
|---|---|---|
| Price | Ücretsiz | 1.0 bir geri bildirim sürümü: hatalar ve eksikler kullanıcıyla görülecek. Ücretsizde App Store Connect vergi ve banka bilgisi istemiyor |
| Availability | Tüm ülkeler | Uygulama yalnız Türkçe ve Türk bankalarının ekstrelerini tanıyor, ama yurt dışındaki Türkçe konuşan kullanıcıyı kapatmanın faydası yok. Ülke kısıtı sonradan değiştirilebilir |
| Pre-Orders | Hayır | Gerek yok |
| Distribution | App Store | TestFlight ile iç test önce yapılabilir |

### 12.1 Sonraki sürümlerde gelir — verilen karar

**Plan:** 1.0 ücretsiz çıkar. Kullanım ve geri bildirim görüldükten sonra
uygulama içi satın alma eklenir (tek seferlik "full paket" ve/veya aylık ·
yıllık abonelik). Uygulama App Store'da ücretsiz kalmayı sürdürür; bu, normal
bir güncelleme, ek bir başvuru türü gerektirmiyor.

**Reklam eklenmeyecek.** Gerekçe teknik, tercih değil:

| Ne kırılır | Nasıl |
|---|---|
| Ağ katmanı yok kısıtı | Reklam SDK'sı ağ kullanır; `Scripts/verify-offline.sh` derlemeyi düşürür |
| Üçüncü parti bağımlılık yok kısıtı | Her reklam ağı bir SDK'dır |
| App Privacy etiketi | "Data Not Collected" düşer; reklam kimliği ve izleme beyanı gerekir |
| Mağaza metni ve onboarding | "Verileriniz telefonunuzdan çıkmaz" cümlesi doğruluğunu kaybeder |

Uygulamayı mahremiyeti için indiren kullanıcı ilk reklamda siler; gelir modeli
ürünün tek ayırt edici özelliğini yiyemez.

**Uygulama içi satın alma bu kısıtları kırmaz.** StoreKit ağ trafiğini
Apple'ın çerçevesi üretir, uygulamanın kendi ağ kodu olmaz; satın alma verisi
Apple'da kalır, geliştiriciye kullanıcı verisi gelmez, "Data Not Collected"
bozulmaz. Eklendiğinde iki iş gerekir: `verify-offline.sh` içine StoreKit
için bilinçli ve gerekçeli bir istisna, gizlilik politikasına satın alma
paragrafı. Bu faz kapsamında **yapılmadı**, yalnız kapı açık bırakıldı.

---

## 13. Ekran görüntüleri

Plan, cihaz boyutları ve üretim yöntemi ayrı dosyada: `docs/SCREENSHOTS.md`.

---

## 14. Yükleme öncesi kontrol listesi

- [ ] Bundle ID `com.sessizdefter.app` App Store Connect'te kayıtlı
- [ ] Uygulama kaydı açıldı, Primary Language = Türkçe
- [ ] Gizlilik politikası yayımlandı, URL girildi
- [ ] Destek sayfası yayımlandı, URL girildi
- [ ] İhracat beyanı onaylandı (`docs/EXPORT-COMPLIANCE.md` bölüm 4)
- [ ] Bu dosyadaki metinler App Store Connect'e girildi
- [ ] Ekran görüntüleri yüklendi (`docs/SCREENSHOTS.md`)
- [ ] App Privacy formu "Data Not Collected" olarak kaydedildi
- [ ] Yaş sınırı anketi dolduruldu, sonuç 4+
- [ ] App Review notları ve örnek ekstre PDF'i eklendi
- [ ] `Scripts/archive.sh` dört kapıdan geçti, arşiv üretildi
- [ ] Arşiv Xcode Organizer ya da Transporter ile yüklendi
- [ ] TestFlight'ta iç test yapıldı
