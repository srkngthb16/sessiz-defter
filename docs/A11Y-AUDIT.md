# Erişilebilirlik Denetimi — Faz 10.1

Tarih: 2026-08-16 · Sürüm 1.0.0 (2)

Denetim iki eksende yapıldı: **seslendirme** (VoiceOver etiketleri) ve **yazı
büyüklüğü** (Dynamic Type, `accessibility-extra-extra-extra-large` kademesi).
Kontrast oranları Faz 2'de ölçüldü, `DesignSystemTests/ContrastTests` 17 renk
çiftini her koşuda denetliyor.

## Nasıl doğrulandı

| Eksen | Yöntem | Durum |
|---|---|---|
| Etiket metinleri | `DesignSystemTests/AccessibilityLabelTests`, `FeaturesTests/AccessibilityTests` | Otomatik, her koşuda |
| Tutar okunuşu | `CoreTests` — `Fmt.spoken` | Otomatik |
| Dynamic Type XXXL | Simülatörde `xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`, dört sekme tek tek | Elle, bu fazda |
| Kontrast | `DesignSystemTests/ContrastTests` | Otomatik |
| **VoiceOver'ın kendisi** | **Yapılmadı** — "Açık kalanlar" 1 | — |

## Tutar okunuşu

Ekrandaki dize ile okunan dize ayrıldı: "₺ 842,60" seslendirmede para gibi
duyulmuyor, simgenin ve virgülün okunuşu cihaza göre değişiyor.

| Ekranda | Okunuşu |
|---|---|
| `−₺ 842,60` (gider) | eksi 842 lira 60 kuruş |
| `+₺ 52.400,00` (gelir) | artı 52.400 lira |
| `₺ 47.709,67` (bakiye) | 47.709 lira 67 kuruş |
| `−₺ 1.200,00` (eksi bakiye) | eksi 1.200 lira |
| `%93` | yüzde 93 |

**Kuruş sıfırsa okunmuyor.** Liste taramasında her satırda "sıfır kuruş" duymak
yoruyor. Kaynak: `Core/Fmt.spoken(_:sign:)`.

Yön sözcüğü ("gider", "gelir") etikete yazılmıyor: işaretin karşılığı zaten
okunuyor, "gider eksi 842 lira" aynı bilgiyi iki kez söylüyordu. Transfer
istisna — işareti olmadığı için "transfer, 500 lira" diye okunuyor.

## Ekran ekran

| Ekran | Seslendirme | XXXL yerleşim |
|---|---|---|
| A1–A3 onboarding | Başlık, açıklama ve kart metinleri sırayla; anahtarlar sistem `Toggle` | Sayfa kaydırılabilir, kırpma yok |
| A4 kilit | Sistem `LocalAuthentication` arayüzü | — |
| B1 boş durum | İllüstrasyon `accessibilityHidden`; başlık, açıklama, iki buton okunuyor | Dikey akış, kırpma yok |
| B2 iskelet | Yer tutucu bloklar gizli | — |
| C1–C8 içe aktarma | Adım başlıkları ve hata metinleri okunuyor | Uzun metinler sarıyor |
| D1 dashboard | Bakiye kartı tek cümle: "Toplam net varlık 47.709 lira 67 kuruş, bu ay artı 25.312 lira 7 kuruş, 1 hesap". Gelir/gider kutuları, bütçe ve dağılım satırları ayrı ayrı tek cümle | **Düzeltildi** (aşağıda 6) |
| D2 işlem listesi | Satır tek etiket: açıklama, kategori, hesap, tutar, gerekirse "kontrol gerekiyor". Gün başlığı `isHeader` ve gün toplamını okuyor | Satır dikey düzene geçiyor (mevcut davranış) |
| D4 filtre | Sistem `Form` bileşenleri | Sarma var, kırpma yok |
| D5 detay | Alanlar `LabeledContent` | — |
| E1 bütçeler | Kart tek cümle: "Ulaşım bütçesi aşıldı, yüzde 114, harcanan 1.600 lira, limit 1.400 lira, 200 lira aşıldı". Çubuk gizli, bilgisi cümlede | Kırpma yok |
| E2 bütçe editörü | Sistem `Form` | — |
| E3 raporlar | Grafik tek öğe: etiket "Gelir ve gider trendi grafiği", değeri sözlü özet (dönem sayısı, en yüksek/en düşük gider dönemi, son dönem) | **Düzeltildi** (aşağıda 6) |
| E4 manuel giriş | Sistem `Form` + `decimalPad` | — |
| F1 ayarlar | Sistem `Form`; bölüm altyazıları okunuyor | — |
| F2 mahremiyet raporu | Sayılar metin olarak | — |
| F3 tüm verileri sil | Onay akışı sistem bileşenleri | — |
| Geri bildirim | Gönderilecek metnin tamamı seçilebilir metin olarak okunuyor | Metin sarıyor |

## Bu fazda düzeltilenler

1. **Tutar okunuşu yoktu.** `AmountText` etiketi "gider ₺ 842,60" diyordu; artık
   `Fmt.spoken` üzerinden "eksi 842 lira 60 kuruş".
2. **Hesap maskesi ham okunuyordu.** "Ziraat ••3412" → "Ziraat son dört hane
   3412" (`SpokenText.expandingAccountMask`). Orta nokta da ayraç olarak hiç
   okunmuyordu, virgüle çevrildi.
3. **İşlem satırı parça parça okunuyordu.** `children: .combine` "kontrol
   gerekiyor" rozetini duyurmuyordu; satır tek etikete indirildi.
4. **Bütçe kartı bölme işlemi gibi duyuluyordu**: "1.600,00 / 1.400,00 ₺"
   yerine tam cümle.
5. **Grafik dinlenemiyordu.** Çubuklar tek tek okunuyor, eğilim anlaşılmıyordu;
   grafiğin değeri artık sözlü özet.
6. **XXXL kademesinde tutarlar kırpılıyordu** (simülatörde yakalandı):
   dashboard'da "+₺ 25.…", "+₺ 4…", raporlarda "+₺ 48…". Yan yana duran tutarlar
   erişilebilirlik kademesinde alt alta geçiyor (`DesignSystem/AdaptiveStack`;
   eşik `TransactionRow` ile aynı: `dynamicTypeSize.isAccessibilitySize`).

## Açık kalanlar

1. **VoiceOver'la uçtan uca gezinme yapılmadı.** Etiket metinleri birim testiyle,
   yerleşim simülatörde görsel olarak doğrulandı; VoiceOver'ı simülatörde
   betikle sürmek bu ortamda mümkün olmadı. **Gerçek cihazda bir tur gerekiyor:**
   her sekmede sağa kaydırarak gezinme, okuma sırasının ekrandaki sırayla aynı
   olduğunun ve hiçbir öğenin atlanmadığının doğrulanması.
2. **Rotor ve özel eylemler eklenmedi.** İşlem satırındaki kaydırma jestleri
   (sil, düzenle) `accessibilityActions` olarak sunulmuyor; şu an yalnız detay
   ekranından erişilebiliyorlar.
3. **Azaltılmış hareket** (`accessibilityReduceMotion`) denetlenmedi. Uygulamada
   yalnız açılış ve kilit geçişleri animasyonlu.
4. **Seslendirme dili** cihazın VoiceOver diline bağlı. Etiketler Türkçe;
   İngilizce VoiceOver ile telaffuz bozulur. Uygulama tek dilli, şimdilik kabul.
5. **Audio Graphs** (`accessibilityChartDescriptor`) eklenmedi; sözlü özet
   yeterli görüldü, ses grafiği isteğe bağlı sonraki adım.
