# Ekran Görüntüsü Planı ve Üretimi

App Store Connect'e yüklenecek görüntüler, hangi ekranlar ve nasıl üretildikleri.
Üretim tekrarlanabilir: ham çekim + `Scripts/make-screenshots.swift`.

---

## 1. Hangi boyutlar

| Yuva | Piksel | Durum |
|---|---|---|
| iPhone 6.9" | **1320 × 2868** (dikey) | **Zorunlu.** Üretildi |
| iPhone 6.5" | 1284 × 2778 | Boş bırakılıyor; App Store 6.9"dan ölçekliyor |
| iPad | — | Gerekmiyor: `TARGETED_DEVICE_FAMILY = 1`, uygulama yalnız iPhone |

Cihaz: **iPhone 17 Pro Max** simülatörü (6.9", 440 × 956 punto, 3x).
Yatay görüntü yok — uygulama yalnız dikey (`UISupportedInterfaceOrientations`).

Sayı: App Store 3–10 arası kabul ediyor; altı görüntü üretildi. `01` ve `02`
arama sonucunda küçük önizlemede görünen ikili, bu yüzden ürünün ne olduğunu
ilk iki karede söylüyorlar.

`Scripts/make-screenshots.swift` girdinin 1320 × 2868 olduğunu doğrulamadan
çıktı üretmiyor: yanlış ölçü yüklemede reddediliyor ve hata geç fark ediliyor.

---

## 2. Hangi veriyle

**Örnek defter** (`Domain/Services/SampleLedger.swift`): 20 işlem, "Örnek Banka"
hesabı, biri uyarı biri aşım eşiğinde iki bütçe. Onboarding'in son sayfasındaki
"Örnek veriyle gez" anahtarıyla yükleniyor.

Neden gerçek veri değil: ekran görüntüsü mağazada kalıcı olarak duruyor;
kullanıcının kendi işyeri adları, tutarları ve hesap bakiyesi oraya girmemeli.
Örnek defter zaten üretim kodunda ve TestFlight kullanıcısının da göreceği veri,
yani mağazadaki görüntüyle uygulamanın ilk hâli birbirini tutuyor.

Örnek defterin kayıtları "bugüne" göre üretiliyor; görüntüler yeniden çekilirse
tutarlar aynı kalır, tarihler kayar. Sorun değil — mağazada tarih okunmuyor.

---

## 3. Hangi ekranlar

Sıra mağazadaki sıradır. Ham dosya adı, başlık metnini `make-screenshots.swift`
içindeki tablodan seçen anahtardır.

| # | Ham dosya | Ekran | Başlık bandı | Neden bu ekran |
|---|---|---|---|---|
| 1 | `01-dashboard.png` | D1 Özet | "Defteriniz tek ekranda" | Ürünün tamamını tek karede gösteren ekran: net varlık, bütçe, dağılım |
| 2 | `02-islemler.png` | D2 İşlemler | "İşlemler otomatik kategorilenir" | Asıl vaadin kanıtı: kategorili, hesaplı, tarihli liste |
| 3 | `03-butce.png` | E1 Bütçeler | "Bütçe gün gün takip eder" | Uyarı ve aşım hâli birlikte görünüyor; "günlük harcanabilir" farkı burada |
| 4 | `04-raporlar.png` | E3 Raporlar | "Dönemleri karşılaştırın" | Grafik ve dönem karşılaştırması; bu kategoride beklenen ekran |
| 5 | `05-onboarding.png` | A1 Onboarding | "Uçak modunda da çalışır" | Mahremiyet iddiası ve "neyin olmadığı" listesi |
| 6 | `06-mahremiyet.png` | F2 Mahremiyet raporu | "İddia değil, rapor" | İddianın uygulama içinden doğrulanabildiği ekran |

**Alınmayan ekranlar ve nedenleri:**
- C serisi içe aktarma: en anlatıcı adımı dosya seçici, o da sistem arayüzü —
  mağaza karesinde uygulamanın kendi ekranı durmalı.
- E4 manuel giriş: sistem `Form`'u; tasarımdaki özel tuş takımı henüz yok
  (`docs/COWORK-BRIEFING.md` bölüm 6, madde 8). Eksik olanı mağazada
  göstermenin anlamı yok.
- F3 tüm verileri sil: gerekli ekran ama satmıyor.

---

## 4. Metin katmanı

**Karar (kullanıcı, 2026-08-17):** kısa başlık bandı var, cihaz çerçevesi yok.

- Üstte iki satır: kalın başlık (Archivo Bold 76) + marka renginde alt not
  (Archivo Medium 42). Fontlar `Scripts/font-src` altından yükleniyor, yani
  mağaza görselinin tipografisi uygulamanınkiyle aynı.
- Zemin `bg.canvas` (#F6F8F8) — uygulamanın zemini, görüntü tuvale karışıyor.
- Ekran görüntüsü %82 ölçekli, köşeleri yuvarlatılmış, alttan taşırılmış.
  Tamamını sığdırmak tutarları okunmaz yapıyordu.
- Cihaz çerçevesi çizilmiyor: çerçeve ekran alanının bir kısmını yiyor.
- Başlıklar ekrandaki cümleyi tekrarlamıyor. İlk denemede onboarding başlığı
  ekrandaki başlıkla birebir aynıydı; band boşa gidiyordu.

---

## 5. Üretim

### 5.1 Ham çekim

```bash
xcrun simctl boot "iPhone 17 Pro Max"
```

```bash
xcodebuild build -project SessizDefter.xcodeproj -scheme SessizDefter -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO
```

```bash
xcrun simctl install booted DerivedData/Build/Products/Debug-iphonesimulator/SessizDefter.app
```

```bash
xcrun simctl status_bar booted override --time "09:41" --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
```

```bash
xcrun simctl launch booted com.sessizdefter.app
```

Sonra elle: onboarding'de "Örnek veriyle gez" açılır, "Şimdi değil" ile
bitirilir, her ekran çekilir:

```bash
xcrun simctl io booted screenshot build/screenshots/raw/01-dashboard.png
```

**Kurulum temiz olmalı.** Uygulama zaten kuruluysa onboarding görünmez ve örnek
veri anahtarına ulaşılamaz:

```bash
xcrun simctl uninstall booted com.sessizdefter.app
```

### 5.2 Başlık bandı

```bash
swift Scripts/make-screenshots.swift
```

Girdi `build/screenshots/raw`, çıktı `build/screenshots/appstore`. Çıktılar
gitignore'lu `build/` altında: ikili dosyalar depoya girmiyor, üretim betikten
tekrarlanıyor.

### 5.3 Simülatörde karşılaşılan üç tuzak

Not edilmezse ikinci çekimde aynı yarım saat harcanıyor:

1. **Anahtarlar anlık dokunuşu yutuyor.** `Toggle` üzerine gönderilen tek
   karelik dokunma hiçbir şey yapmıyor; dokunuşun ~150 ms basılı kalması
   gerekiyor. "Örnek veriyle gez" anahtarı beş denemede bu yüzden açılmadı.
2. **Bildirim izni istemi Bütçe sekmesinde çıkıyor** ve ekranı kaplıyor. Önce
   sekmeye girip istemi cevaplamak, sonra çekmek gerekiyor.
3. **Durum çubuğu** `simctl status_bar override` ile sabitlenmezse her karede
   farklı saat ve pil görünüyor.

---

## 6. Yükleme kontrol listesi

- [ ] `build/screenshots/appstore` altındaki altı PNG 1320 × 2868
- [ ] Görüntülerde gerçek kişisel veri yok (örnek defter kullanıldı)
- [ ] Banka markası, logosu ya da banka renk kimliği yok (Guideline 1.4.1 / 5.2.1)
- [ ] Başlık metinleri mağaza açıklamasıyla çelişmiyor
- [ ] App Store Connect > 6.9" yuvasına sırayla yüklendi (01 → 06)
