# Dayanıklılık Denetimi — Faz 10.3

Tarih: 2026-08-17 · Sürüm 1.0.0 (2)

Beş senaryo: yedek al/geri yükle, uçak modu, düşük depolama, içe aktarma
sırasında uygulamanın ölmesi, yarım kalan ImportBatch.

## 1. Yedek al / geri yükle — simülatörde uçtan uca ✔

Adımlar (iPhone 16e, iOS 26.1 simülatörü):

1. Örnek defter yüklü (20 işlem, "Örnek Banka", 2 bütçe).
2. Ayarlar > Yedek dışa aktar > parola > Dosyalar'a kaydet.
   Sonuç: `SessizDefter-2026-08-17.sdb`, 21 KB.
3. Ayarlar > Örnek veriyi temizle. Depoda doğrulandı: 0 işlem, 0 bütçe, 0 parti.
4. Ayarlar > Yedekten geri yükle > dosya seç > parola.
   Depoda doğrulandı: 20 işlem, "Örnek Banka" hesabı, 2 bütçe, parti
   `Örnek veri | addedCount 20 | isComplete 1`.

Şifreli dosya gerçekten okunuyor, arşiv defterin yerine geçiyor, sayılar birebir
dönüyor. Birim testleri (`PersistenceTests/BackupServiceTests`) arşivin içeriğini
zaten denetliyordu; buradaki fark dosya seçici, güvenlik kapsamlı URL ve parola
akışının gerçek yollarla çalıştığının görülmesi.

**Kullanıcı cihazda da doğruladı** (2026-08-17): yedek dışa aktarma ve geri
yükleme sorunsuz çalışıyor.

**Bu adımda bir hata çıktı ve düzeltildi:** "Tüm verileri sil" onayı "SİL" ile
tam eşleşme arıyordu. Klavyenin otomatik büyük harf kuralı "sil" yazınca cihaza
göre "SIL" (noktasız I) üretiyor; doğru sözcük yazılsa bile buton hiç açılmıyor
ve kullanıcı verisini silemiyordu. Karşılaştırma artık Türkçe harf katlamasıyla:
"sil", "SIL", "SİL", "sıl" kabul, "SILME" değil (`String.trFoldedUpper`,
`FeaturesTests/DeleteConfirmationTests`). Cihazda doğrulandı.

## 2. İçe aktarma sırasında uygulamanın ölmesi ✔

İçe aktarma iki aşamalı yazıyor:

1. Parti kaydı `isComplete = false` ile açılır.
2. İşlemler tek yazma işleminde yazılır (biri düşerse hiçbiri kalmaz).
3. Parti `isComplete = true` ile tamamlanır.

Açılışta `ImportRecovery.repair` tamamlanmamış partileri kapatıyor:

- Hiç satır yazılmamışsa parti kaydı silinir, defterde iz kalmaz.
- Satır yazılmışsa parti **gerçekte yazılan** sayıyla tamamlanır. İşlemler
  silinmiyor: kullanıcının verisini silmek geri alınamaz bir karar olurdu.

Neden partiden bakılıyor: parti tablosu birkaç satır, işlem tablosu on binlerce.
Yarım kalan işi işlemleri tarayarak aramak 10.000 kayıtta yarım saniye sürerdi
(`docs/PERFORMANCE.md`).

**Simülatörde doğrulandı:** depodaki parti elle `isComplete = 0, addedCount = 999`
yapıldı (ölmüş uygulamanın bırakacağı hâl), uygulama yeniden açıldı; parti
`addedCount 20, isComplete 1` olarak onarıldı, 20 işlem yerinde kaldı.

Birim testleri: `FeaturesTests/ResilienceTests` — boş parti silinir, yarım parti
gerçek sayıyla tamamlanır, tamamlanmış partiye dokunulmaz, ikinci onarım boş geçer.

## 3. Yarım kalan ImportBatch — yedek dosyasında ✔

`isComplete` alanı arşive de giriyor. Alan 10.3'te eklendiği için eski yedeklerde
yok: `ImportBatchEntity` çözümlemesi alan yoksa **tamamlanmış** kabul ediyor.
Aksi hâlde eski yedekten dönen geçmiş içe aktarmalar yarım görünür ve onarım
onları yeniden yazardı. Testler: "Yedek arşivi yarım kalan parti işaretini taşır",
"Alanı olmayan eski yedek tamamlanmış sayılır".

## 4. Uçak modu ✔ (yapı gereği)

Uygulamada ağ kodu yok: `URLSession`, `Network`, `CloudKit`, analytics/crash SDK'sı
yok; `Info.plist`'te ağ anahtarı yok. `Scripts/verify-offline.sh` her commit'te
kaynak ağacını tarıyor ve ağ izi bulursa build'i düşürüyor (pre-commit hook'una
bağlı). Uçak modunda davranışın değişebileceği tek yer bir ağ çağrısı olurdu;
öyle bir çağrı yok.

Simülatörde uçak modu gerçekten açılamıyor (`simctl status_bar` yalnız durum
çubuğunun görüntüsünü değiştiriyor), bu yüzden ekran doğrulaması yapılmadı.

## 5. Düşük depolama ⚠ kısmen

Simülatörde disk doldurulup gerçek "disk dolu" hatası üretilmedi. Yazma
yollarının hata karşısındaki davranışı kodda tanımlı:

- Toplu yazma (`upsertAll`) hata alırsa `rollback` yapıyor: yarım parti kalmıyor.
- Yedek yazımı düşerse kullanıcı "Yedek yazılamadı." mesajını görüyor ve hata
  sayacına bir yedekleme hatası işleniyor (`Diagnostics.backup`).
- İçe aktarma düşerse parti tamamlanmıyor, açılışta onarım devreye giriyor
  (bölüm 2).

**Kalan:** gerçek cihazda diski doldurup yedek dışa aktarma ve içe aktarma
denemesi.

## Özet

| Senaryo | Durum |
|---|---|
| Yedek al / geri yükle | Simülatörde uçtan uca doğrulandı |
| İçe aktarma sırasında ölüm | Kod düzeltildi, simülatörde doğrulandı |
| Yarım kalan ImportBatch | Onarım + arşiv uyumluluğu, testlerle |
| Uçak modu | Yapı gereği; `verify-offline.sh` denetliyor |
| Düşük depolama | Kısmen: hata yolları tanımlı, gerçek disk dolu denenmedi |
| "Tüm verileri sil" akışı | Hata bulundu ve düzeltildi; cihazda doğrulandı |
