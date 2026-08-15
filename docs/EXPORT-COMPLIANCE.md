# İhracat / Şifreleme Beyanı — Analiz

**Durum: taslak. Hukuki hüküm değil.** Aşağıdaki değerlendirme koddaki gerçek
kullanımı belgeler ve Apple'ın muafiyet maddelerinden hangisine denk düştüğüne
dair bir okuma önerir. Nihai beyan yükümlülüğü geliştiriciye aittir; App Store
Connect'te işaretlemeden önce doğrulanmalı.

---

## 1. Koddaki tüm kripto kullanımları

Kaynak taramasıyla çıkarıldı. Test kodu hariç, yalnızca mağazaya giden ikilideki kullanım.

| # | Nerede | Ne | Amaç |
|---|---|---|---|
| 1 | `Core/Security/PasswordCrypto.swift:40,71,72` | **AES-256-GCM** (CryptoKit `AES.GCM.seal` / `.open`) | Kullanıcının kendi başlattığı yerel yedek dosyasını şifreler ve açar |
| 2 | `Core/Security/PasswordCrypto.swift:94` | **PBKDF2-HMAC-SHA256** (CommonCrypto `CCKeyDerivationPBKDF`, 600.000 tur) | Yedek parolasını germe; kaba kuvvet denemesini yavaşlatır |
| 3 | `Core/Security/PasswordCrypto.swift:82` | **HKDF-SHA256** (CryptoKit) | Gerilen anahtardan amaca özel şifreleme anahtarı türetme |
| 4 | `Core/Security/PasswordCrypto.swift:35` | **SecRandomCopyBytes** | Yedek başına rastgele tuz üretimi |
| 5 | `Core/DuplicateHash.swift:14` | **SHA-256** (CryptoKit `SHA256.hash`) | Mükerrer işlem tespiti için parmak izi. Gizlilik amacı yok, kimlik doğrulama yok |
| 6 | `Core/Security/Keychain.swift` | **Keychain Services** (`SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`) | Hassas alan anahtarlarını iOS'un kendi korumalı deposunda tutar |
| 7 | Sistem düzeyi | **FileProtection.complete** (`StoreFactory.applyProtection`) | iOS'un dosya şifrelemesi; uygulama kendi algoritmasını uygulamıyor |

**Ağ üzerinden şifreleme yoktur.** Uygulamada TLS, sertifika doğrulama, anahtar
değişimi, imzalama ya da herhangi bir iletişim kriptografisi bulunmuyor —
ağ katmanı hiç yazılmadı (`Scripts/verify-offline.sh` bunu her commit'te doğruluyor).

---

## 2. Değerlendirme

Kullanımların tamamı iki grupta toplanıyor:

**a) İşletim sisteminin kendi kriptografisi (6, 7)**
Keychain ve FileProtection Apple'ın sağladığı hizmetler. Uygulama algoritma
uygulamıyor, yalnızca sistem API'sini çağırıyor.

**b) Kullanıcının kendi verisinin, kendi cihazında, kendi parolasıyla korunması (1–4)**
Yedek dosyası kullanıcının açık eylemiyle üretilir, kullanıcının seçtiği konuma
yazılır ve yalnızca kullanıcının bildiği parolayla açılır. Şifreleme başka bir
tarafa veri iletmek için değil, cihazda duran dosyayı korumak için kullanılır.

**c) Kriptografik olmayan özet (5)**
SHA-256 burada gizlilik ya da kimlik doğrulama için değil, aynı işlemin iki kez
kaydedilmesini önleyen bir parmak izi olarak kullanılıyor.

### Muafiyet okuması

Bu tablo, Apple'ın "Does your app use encryption?" akışındaki muafiyet
seçenekleriyle şöyle örtüşüyor **gibi görünüyor** — doğrulanması gerekiyor:

- Apple'ın belgelediği muafiyetler arasında **"yalnızca kullanıcının kendi
  verisinin korunması amacıyla kullanılan şifreleme"** ve **"işletim sisteminin
  sağladığı şifrelemenin kullanılması"** maddeleri bulunuyor. Buradaki kullanımların
  tamamı bu iki tanımın içinde kalıyor.
- Uygulama şifreleme işlevini bir hizmet olarak sunmuyor, üçüncü tarafa veri
  iletmiyor, özel (proprietary) bir algoritma içermiyor. Kullanılan algoritmaların
  hepsi standart ve Apple'ın kendi çerçevelerinden geliyor.

**Sonuç önerisi:** `ITSAppUsesNonExemptEncryption = false` değeri bu okumaya göre
doğru görünüyor ve Info.plist'te bu haliyle duruyor.

### Kesin olmayan noktalar

- Muafiyet maddelerinin tam metni Apple'ın belgelerinde ve ABD ihracat
  düzenlemelerinde (EAR, Category 5 Part 2) yer alıyor; bu doküman o metinleri
  alıntılamıyor, yalnızca kullanımı belgeliyor.
- Türkiye'den yayın yapmanın ek bir yerel yükümlülük doğurup doğurmadığı
  incelenmedi.
- **Bu noktalarda kesin hüküm verilmedi. Beyanı işaretlemeden önce Apple'ın güncel
  akışındaki soruları okuyup, gerekiyorsa hukuki danışmanlıkla doğrulanması gerekiyor.**

---

## 3. App Store Connect'te karşılaşılacak sorular

TestFlight'a ilk yükleme yapıldığında sorulur. Yukarıdaki okumaya göre beklenen cevaplar:

| Soru | Beklenen cevap | Dayanak |
|---|---|---|
| "Does your app use encryption?" | **Evet** | AES-GCM ve PBKDF2 kullanılıyor; "hayır" demek yanlış olur |
| "Does your app qualify for any of the exemptions?" | **Evet** | Yalnızca kullanıcı verisinin cihazda korunması + sistem şifrelemesi |
| Hangi muafiyet | Kullanıcının kendi verisinin korunması / işletim sistemi şifrelemesi | Bölüm 2 |
| "Is your app designed to use cryptography for a purpose other than..." | **Hayır** | Ağ, kimlik doğrulama, DRM, hizmet olarak şifreleme yok |
| Yıllık self-classification raporu | Muafiyet geçerliyse gerekmiyor | Doğrulanmalı |

`ITSAppUsesNonExemptEncryption = false` Info.plist'te bulunduğu sürece bu sorular
her yüklemede tekrar sorulmaz.

---

## 4. Onay bekleyen karar

Bu dosyadaki okuma senin onayınla kesinleşir. İki seçenek:

1. **Mevcut hâli bırak** — `ITSAppUsesNonExemptEncryption = false`. Yukarıdaki
   analiz bunu destekliyor.
2. **Anahtarı kaldır** — o zaman App Store Connect her yüklemede ihracat sorularını
   sorar ve cevapları elle verirsin. Daha yavaş ama beyanı her seferinde bilinçli
   yapmış olursun.

Değişiklik gerekiyorsa `App/Info.plist` içindeki `ITSAppUsesNonExemptEncryption`
anahtarı düzenlenir.
