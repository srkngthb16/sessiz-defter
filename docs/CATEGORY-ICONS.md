# Kategori simgeleri — SF Symbols eşlemesi

Tasarım dosyası kategori ikonlarını "harf monogram yer tutucu" diye işaretliyor ve
"üretimde tek çizgi SF Symbols" diyor (`Sessiz Defter - Mobil Ekranlar.dc.html`, satır 58).
Bu dosya o eşlemenin tamamını ve neden bu simgelerin seçildiğini yazar.

**Tek kaynak kod tarafında:** `Packages/Domain/Sources/Domain/Entities/DefaultCategories.swift`.
Ayarlar'daki simge seçici (`CategoryManagementView`) listeyi
`DefaultCategories.symbolChoices()`'tan alır. Buradaki tablo o kaynağın açıklamasıdır;
ikisi ayrışırsa kaynak kod geçerlidir ve bu dosya güncellenir.

**Doğrulama:** `FeaturesTests/CategoryIconTests` her adı `UIImage(systemName:)` ile
çözer. Yanlış yazılmış bir simge adı derlemeyi düşürmez, ekranda sessizce boş kutu
çizer — bu yüzden test simülatörde koşuyor.

## Kurallar

1. **Dolgusuz varyant.** `.fill` biçimleri kullanılmıyor: rozet zaten renk dolgulu,
   içine dolu simge girince ikon okunmuyor. (`CategoryBadge`, ağırlık `.medium`,
   punto rozetin %42'si.)
2. **Marka işaretiyle çakışma yok.** `book.closed` uygulamanın kendi işareti
   (açılış ekranı, App Switcher maskesi, boş durum illüstrasyonu). Kategori
   listesinde `book` kullanılmıyor.
3. **Yön ikonuyla çakışma yok.** `arrow.down.left` / `arrow.up.right` /
   `arrow.left.arrow.right` işlem yönünü anlatır; kategori simgesi ok içermez.
4. **Sistem eylemleriyle karışmayan simge.** Araç çubuğu anlamı taşıyan simgeler
   (`plus`, `trash`, `square.and.arrow.up`) kategori olmaz.
5. **Türkiye bağlamı.** Ulaşım harcamasının çoğu toplu taşıma; "araba" varsayılmıyor.

## Gider kategorileri (13)

| Kategori | SF Symbol | Renk yuvası | Neden |
|---|---|---|---|
| Market | `cart` | 0 | Alışveriş arabası market fişinin evrensel karşılığı. `basket` daha küçük ölçekli alışverişi çağrıştırıyor. |
| Ulaşım | `bus` | 1 | Metro/otobüs/İstanbulkart kalemleri baskın. Önceki `car` yalnız sürücüyü anlatıyordu; akaryakıt da bu kategoride kalıyor. |
| Faturalar | `doc.text` | 2 | Fatura belgedir. `bolt` yalnız elektriği, `drop` yalnız suyu anlatırdı. |
| Sağlık | `cross.case` | 3 | Sağlık çantası; `heart` bu listede Bağış'ta kullanıldığı için serbest değil. |
| Abonelik | `arrow.triangle.2.circlepath` | 4 | Yinelenen ödeme = dönen ok. Önceki `repeat` bir medya oynatma glifi. |
| Ev | `house` | 5 | Kira, aidat, ev bakımı. |
| Eğitim | `graduationcap` | 6 | Önceki `book` marka işaretiyle karışıyordu (kural 2). |
| Eğlence | `theatermasks` | 7 | Sinema, konser, tiyatro. |
| Alışveriş | `bag` | 8 | Market dışı perakende; `cart` Market'te. |
| Kişisel bakım | `scissors` | 9 | Kuaför/berber baskın kalem. `comb` daha dar. |
| Bağış | `heart` | 10 | Dolgusuz kalp bağışın alışılmış karşılığı. |
| Yeme-içme | `fork.knife` | 10 | Renk yuvasını Bağış ile paylaşır (12 yuva dolu, 13 gider var); simge paylaşılmaz. |
| Diğer | `ellipsis.circle` | 11 | Sınıflanmamış kalem. Rozet içinde durduğu için araç çubuğundaki "daha fazla" anlamıyla karışmıyor. |

## Gelir kategorileri (3)

| Kategori | SF Symbol | Renk yuvası | Neden |
|---|---|---|---|
| Maaş | `banknote` | 3 | Düzenli nakit giriş. |
| Serbest çalışma | `laptopcomputer` | 6 | Fatura kesilen iş; `briefcase` maaşlı işi de çağrıştırıyor. |
| Diğer gelir | `plus.circle` | 11 | Sınıflanmamış giriş. Gelir yönü ayrıca `arrow.down.left` ile gösterildiği için artı işareti yönle çelişmiyor. |

Gelir kategorileri renk yuvalarını gider kategorileriyle paylaşır: 12 yuva gider
listesi için tasarlandı, gelir listesi ayrı bir renk ailesi istemiyor.

## Seçicideki ek simgeler

Kullanıcı kendi kategorisini açtığında varsayılanların dışında şunlar sunulur:

`tag` (başlangıç değeri) · `creditcard` · `gift` · `pawprint` · `airplane` ·
`wrench.and.screwdriver` · `dumbbell` · `gamecontroller` · `cup.and.saucer` ·
`building.columns`

Liste bilinçli olarak kısa: seçici uzadıkça karar süresi uzuyor ve simgeler
birbirine benzemeye başlıyor. Yeni simge eklenirse kural 1–4 uygulanır ve
`CategoryIconTests` listeyi kendiliğinden denetler.

## Değişiklik notu

Faz 9.3'te değişen üç eşleme: Ulaşım `car → bus`, Abonelik `repeat →
arrow.triangle.2.circlepath`, Eğitim `book → graduationcap`. Değişiklik yalnızca
ilk açılışta yazılan tohum listesini etkiler; mevcut kurulumlarda kullanıcının
kategorileri veritabanında olduğu gibi kalır.
