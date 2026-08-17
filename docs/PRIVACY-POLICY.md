# Sessiz Defter — Gizlilik Politikası

**Yürürlük tarihi:** 17 Ağustos 2026
**Uygulama sürümü:** 1.0.0

Bu sayfa yayımlanmak üzere yazıldı: App Store Connect'in istediği "Privacy
Policy URL" bu metnin adresini gösterecek. İç belge değil, kullanıcının
okuyacağı metindir.

---

## 1. Kısa cevap

**Sessiz Defter hiçbir veri toplamıyor.**

Bu cümle bir söz değil, uygulamanın yapısı: uygulamanın ağ katmanı hiç
yazılmadı. Sunucumuz yok, hesap sistemimiz yok, analitik ya da çökme raporu
aracımız yok, üçüncü taraf yazılım kitaplığı kullanmıyoruz. Verinizi
toplamıyoruz çünkü verinizin bize ulaşabileceği bir yol bulunmuyor.

Bunu kendiniz sınayabilirsiniz — nasıl olduğu bölüm 7'de.

---

## 2. Cihazınızda ne duruyor

Girdiğiniz ve ürettiğiniz her şey yalnızca telefonunuzda, uygulamanın kendi
korumalı alanında durur:

| Ne | Nerede | Nasıl korunuyor |
|---|---|---|
| İşlemler, hesaplar, bütçeler, kategoriler, kurallar | Uygulamanın yerel veritabanı | iOS dosya koruması en yüksek kademede (`FileProtection.complete`): telefon kilitliyken dosya şifreli kalır |
| Uygulama ayarları (kilit tercihi, tema, otomatik kilit süresi) | Uygulamanın kendi tercih deposu | Yalnızca bu uygulama okuyabilir |
| Yedek şifrelemesine ait hassas alanlar | iOS Keychain | Yalnızca bu cihazda, yalnızca telefon kilidi açıkken erişilebilir |

**Saklamadıklarımız:** İçe aktardığınız PDF ekstrenin kopyası tutulmaz. Dosya
okunur, işlemler çıkarılır, dosya bırakılır. Uygulama ekstre dosyanızı ne
kopyalar ne de taşır.

Banka şifreniz, kart numaranız, TC kimlik numaranız, adınız, e-posta adresiniz
ya da telefon numaranız hiçbir yerde istenmez. Uygulama bunları soracak bir
ekran içermiyor.

---

## 3. Cihazınızdan çıkan tek şey: sizin başlattığınız dosyalar

Uygulama kendiliğinden hiçbir şey göndermez. Yalnızca sizin açık bir eylemle
ürettiğiniz üç dosya cihazın dışına çıkabilir; üçünde de nereye gideceğine
siz karar verirsiniz:

**Şifreli yedek.** Ayarlar > Yedek al. Defterinizin tamamı, sizin belirlediğiniz
parolayla AES-256-GCM ile şifrelenmiş tek dosya olur. Parolayı biz bilmeyiz,
saklamayız ve kurtaramayız — parolayı kaybederseniz yedek açılamaz. Dosyayı
iCloud Drive'a, bilgisayarınıza ya da başka bir yere kaydetmek sizin
seçiminizdir; oradaki gizlilik o hizmetin kurallarına tabidir.

**Geri bildirim metni.** Ayarlar > Geri bildirim gönder. Gönderilecek metnin
tamamı, gönderilmeden önce ekranda durur. İçinde şunlar bulunur: uygulama
sürümü, cihaz model kodu (örneğin `iPhone17,5`), iOS sürümü, kaç işlem/hesap/
bütçe kaydınız olduğu ve üç anonim hata sayacı. İçinde **bulunmayanlar:**
tutarlar, işyeri adları, hesap adları, dosya adları, tarihler ve hata
metinleri. Metni kime göndereceğinizi sistem paylaşım sayfasında siz
seçersiniz; uygulama kimseye bağlanmaz.

**Anonim ayrıştırma örneği.** Bir ekstre doğru okunamadığında, sorunu
gösteren birkaç satırı anonimleştirilmiş olarak paylaşabilirsiniz. Rakamlar
ve isimler maskelenir; paylaşılacak metnin tamamını yine gönderimden önce
ekranda görürsünüz.

---

## 4. İzinler

| İzin | Ne için | Ne zaman |
|---|---|---|
| Dosyalar (okuma) | Yalnızca sizin seçtiğiniz PDF ekstreyi okumak | Ekstre içe aktarırken |
| Face ID / Touch ID | Yalnızca uygulama kilidini açmak. Doğrulama iOS tarafından yapılır; uygulama biyometrik verinizi görmez | Kilidi açtıysanız |
| Bildirimler | Bütçe uyarısı ve aşım bildirimi. Bildirim cihazda üretilir, sunucudan gelmez | Bütçe kurduysanız |

Bildirim metninde tutar yazılmaz: kilit ekranı bakiyenizi göstermemeli.

**İstenmeyen izinler:** konum, kamera, fotoğraflar, mikrofon, kişiler, takvim,
sağlık verisi, reklam kimliği (IDFA). Uygulama bu izinlerin hiçbirini istemez.

---

## 5. İzleme, reklam, üçüncü taraflar

- Uygulama sizi izlemez. Reklam kimliğinizi okumaz, farklı uygulamalar
  arasında profilinizi çıkarmaz. iOS'un izleme izni penceresi hiç görünmez.
- Reklam gösterilmez.
- Üçüncü taraf hiçbir yazılım kitaplığı kullanılmıyor. Uygulamanın içinde
  yalnızca Apple'ın kendi çerçeveleri ve iki açık lisanslı yazı tipi var.
- Verinizi kimseye satmıyoruz, kiralamıyoruz, paylaşmıyoruz — elimizde
  olmayan bir şeyi paylaşamayız.

Bize destek amacıyla kendiniz e-posta yazarsanız, o yazışmanın içeriği doğal
olarak bize ulaşır. Bu, uygulamanın veri toplaması değil, sizin kurduğunuz
bir iletişimdir; yazışmayı sorunun çözümü için kullanır, başka bir amaçla
işlemeyiz.

---

## 6. Verinizin silinmesi

Verinizi silmek için bize başvurmanız gerekmez, çünkü bizde bir kopyası yok:

- Tek tek kayıtları uygulamadan silebilirsiniz.
- Ayarlar > Tüm verileri sil: defterin tamamını, ayarları ve hata sayaçlarını
  siler. Geri alınamaz.
- Uygulamayı telefonunuzdan kaldırmak, uygulamanın tuttuğu her şeyi birlikte
  siler.

Kendi kaydettiğiniz yedek dosyaları bu işlemlerden etkilenmez; onları
koyduğunuz yerden siz silersiniz.

---

## 7. Bu metni nasıl doğrularsınız

Gizlilik politikaları genellikle güvenmenizi ister. Bunu sınamanız için üç yol:

1. **Uçak modu.** Telefonu uçak moduna alın ve uygulamayı baştan sona
   kullanın: ekstre içe aktarma, kategorileme, bütçe, rapor, yedek. Hepsi
   çalışır. Sunucuya ihtiyaç duyan bir uygulama bunu yapamaz.
2. **Uygulamanın içindeki mahremiyet raporu.** Ayarlar > Mahremiyet raporu,
   hangi iznin kullanıldığını ve kullanılmadığını tek ekranda gösterir;
   cihazınızda kaç kayıt olduğunu ve saklanan ekstre kopyası sayısını
   (sıfır) listeler.
3. **Kaynak kodu.** Uygulamanın kaynak kodu herkese açık:
   <https://github.com/srkngthb16/sessiz-defter>. Depoda
   `Scripts/verify-offline.sh` adlı bir denetim betiği var; kaynak ağacında ağ
   kullanımı arar ve bulursa derlemeyi düşürür. Her commit'te ve her yayın
   arşivinde çalışır. Yani "ağ kodu yok" cümlesi bir vaat değil, derlemenin
   geçme koşulu.

---

## 8. Çocuklar

Uygulama çocuklara yönelik değildir ve "Çocuklar" (Kids) kategorisinde yer
almaz. Yaşa bakılmaksızın hiç kimseden veri toplanmadığı için çocuklara ait
veri de toplanmaz.

---

## 9. Yasal çerçeve

Kişisel verilerin korunmasına dair mevzuat (KVKK, GDPR ve benzerleri) veri
sorumlusuna, topladığı veri üzerinden yükümlülük getirir: erişim, düzeltme,
silme, taşınabilirlik ve itiraz hakları. Sessiz Defter'de bu hakların
uygulanacağı bir veri havuzu yoktur — verilerinizi biz değil siz tutarsınız
ve doğrudan cihazınızdan yönetirsiniz.

- **Erişim ve taşınabilirlik:** Yedek alma özelliği defterinizin tamamını tek
  dosya olarak dışa aktarır.
- **Düzeltme:** Her kaydı uygulama içinde düzenleyebilirsiniz.
- **Silme:** Bölüm 6.

Uygulamanın veri aktardığı bir yurt dışı sunucusu yoktur; veri hiç
aktarılmadığı için sınır ötesi veri aktarımı da söz konusu değildir.

---

## 10. Bu politikadaki değişiklikler

Uygulama gizliliği etkileyen bir değişiklik alırsa bu sayfa güncellenir ve
üstteki yürürlük tarihi değişir. Değişiklikler App Store'daki sürüm notlarında
da belirtilir. Bu sayfanın geçmiş sürümleri kaynak kodu deposunda görülebilir.

---

## 11. İletişim

*(Destek e-posta adresi buraya yazılacak — App Store Connect'teki destek
adresiyle aynı olmalı.)*

Uygulamanın kaynak kodu ve sorun bildirimi:
<https://github.com/srkngthb16/sessiz-defter>
