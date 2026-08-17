# Performans Ölçümü — Faz 10.2

Tarih: 2026-08-16 · Sürüm 1.0.0 (2)

Ölçüm 10.000 işlemlik defterde yapıldı. Üretici:
`DomainTestSupport/LargeLedger.swift` — tohumlu rastgelelik (SplitMix64), iki yıla
yayılmış kayıtlar, üç hesap, 16 kategori. Tohum sabit; aynı veri üretilmezse
sayılar karşılaştırılamaz.

Testler: `PersistenceTests/PerformanceTests`, bellek içi SwiftData kabı,
iPhone 17 Pro simülatörü. Eşik **250 ms** — kullanıcı listeyi kaydırırken ya da
sekme değiştirirken bunun üstü "takıldı" diye hissediliyor.

## Sonuçlar

| İşlem | Önce | Sonra | Not |
|---|---|---|---|
| 10.000 kaydın yazılması | ~130 s | ~1,5 s | Testin kurulum süresi; kayıt başına "var mı" sorgusu kalktı |
| Liste (ilk sayfa, 200 satır) | 456 ms | < 250 ms | Sınır artık store tarafında |
| Arama ("Migros") | 718 ms | < 250 ms | Arama store tarafında, hazır sütunda |
| Sayım | 458 ms | < 250 ms | `fetchCount`, satır okumadan |
| Dönem sorgusu (bir ay) | < 250 ms | < 250 ms | Zaten yüklemle süzülüyordu |
| Dashboard açılışı — sekme değişimi | ~450 ms | < 250 ms | Toplamlar önbellekten |
| Dashboard açılışı — ilk hesap | ~450 ms | ~460 ms | **Eşiğin üstünde**, aşağıda |
| Rapor hesabı (dağılım + özet) | < 250 ms | < 250 ms | Bellekte, 10.000 satırda sorun değil |
| Gün gruplaması | < 250 ms | < 250 ms | — |

"Önce" sayıları düzeltme öncesi koşudan. Testler tam süreyi raporlamıyor, eşiği
aşınca düşüyor: makineye göre oynayan bir sayıyı belgeye yazmak yanıltıcı olurdu.

## Yapılan düzeltmeler

1. **Toplu yazma karesel çalışıyordu.** `upsertAll` her kayıt için ayrı bir
   "bu id var mı" sorgusu atıyordu ve her sorgu büyüyen tabloyu tarıyordu. Var
   olan kayıtlar artık tek sorguyla alınıp sözlüğe konuyor. 10.000 satırlık içe
   aktarma dakikalardan saniyelere indi — en büyük tek kazanç.
2. **Biçimlendirici satır başına kuruluyordu.** `Fmt.amount` her çağrıda yeni
   `NumberFormatter` yapıyordu; aramada satır başına bir tane. Biçimlendiriciler
   tek örneğe alındı.
3. **Sayım tüm satırları varlığa çeviriyordu.** Tarih dışında filtre yoksa
   `fetchCount` kullanılıyor, satırlar hiç okunmuyor.
4. **Arama tüm defteri belleğe alıyordu.** İşlemlere `searchIndex` sütunu eklendi
   (açıklama + not + etiketler + tutarın yazılı hali, tr_TR büyük harfe çevrilmiş).
   Arama artık `#Predicate` ile store tarafında; kural tek yerde:
   `TransactionEntity.searchIndexText`.
5. **Liste tüm defteri okuyordu.** İşlem listesi 200'er satır yükleniyor, son
   satır göründüğünde sonraki sayfa geliyor (`TransactionsModel.loadMore`).
   Sınır, başka filtre kalmadığında `FetchDescriptor.fetchLimit` ile store
   tarafında uygulanıyor — elenecek satırlar sınırı doldurup sonucu eksiltmesin.
6. **Dashboard tüm defteri okuyordu.** Net varlık `signedTotalsByAccount()` ile
   toplamlardan, ay kartları dönem sorgusundan, son işlemler sınırlı sorgudan
   geliyor.

## Eşiğin üstünde kalan tek yol: net varlık ilk hesabı

10.000 satırın toplanması ~460 ms sürüyor ve iOS 17 SwiftData'da toplama (SUM)
sorgusu yok — satırlar okunmak zorunda. `propertiesToFetch` ile yalnız dört sütun
okumak ölçülebilir kazanç vermedi.

Şimdiki durum: toplam actor içinde tutuluyor, her işlem yazımı düşürüyor. Yani
maliyet **açılışta bir kez** ve **her yazmadan sonra bir kez** ödeniyor; sekme
değiştirmek bedava. Tasarımda B2 iskeleti zaten 200 ms'yi geçen sorgular için var,
bu yolu örtüyor.

**Karar (2026-08-17, kullanıcı onayıyla): şimdiki hâl kalıyor.** Denormalize
toplam tablosu ilk hesabı milisaniyeye indirirdi ama yedekten geri yükleme, toplu
silme ve içe aktarma yollarının hepsine "toplamı da güncelle" borcu yazardı;
biri unutulduğunda bakiye sessizce yanlış görünür. 10.000 işlem tipik kullanıcı
için üst sınır ve açılıştaki tek seferlik yarım saniyeyi B2 iskeleti örtüyor.
Defter bundan çok büyürse karar yeniden açılır.

## Simülatörde yakalanan hata

Arama örnek defterde hiçbir şey bulmuyordu. `searchIndex` sütunu sonradan
eklendiği için eski kayıtlarda değer boş dize değil **NULL** kalıyor ve
`$0.searchIndex.isEmpty` yüklemi o satırları hiç görmüyordu; geri doldurma da bu
yüzden çalışmıyordu. Doldurma artık yüklemle süzmüyor, satırları okuyup gerçek
değerle karşılaştırıyor. Uygulama açılışında bir kez çalışıyor
(`searchIndex.backfilled.v1` anahtarı), sonraki yazımlar sütunu kendisi dolduruyor.
Regresyon testi: "Arama sütunu boş kalmış kayıtlar geri doldurulunca bulunur".

## Ölçülmeyenler

1. **Bellek ve sızıntı profillemesi** yapılmadı (Instruments). Faz 10.2 planında
   vardı, bu turda kapsanmadı.
2. **Gerçek cihazda ölçüm yapılmadı.** Simülatörün diski ve işlemcisi Mac'in;
   telefonda sayılar farklı çıkar. Cihazda bir tur gerekiyor.
3. **Kaydırma akıcılığı** (kare süresi) ölçülmedi; sorgu süreleri ölçüldü.
   Sayfalama sonrası listede aynı anda en çok 200 satır var.
