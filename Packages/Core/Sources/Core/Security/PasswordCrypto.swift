import CommonCrypto
import CryptoKit
import Foundation

/// Parola korumalı yerel yedek. Buluta hiçbir şey gitmez; dosyayı kullanıcı seçtiği
/// konuma yazar.
///
/// Anahtar iki aşamada üretilir:
/// 1. PBKDF2-HMAC-SHA256 ile parola gerilir. HKDF tek başına yeterli değil —
///    hızlıdır ve kaba kuvvet denemesini yavaşlatmaz; yedek dosyası ele geçerse
///    zayıf parola kısa sürede kırılır.
/// 2. Gerilen anahtardan HKDF-SHA256 ile amaca özel şifreleme anahtarı türetilir.
public enum PasswordCrypto {
    public enum Failure: Error, Equatable {
        case weakPassword
        case keyDerivationFailed
        case corruptedArchive
        case wrongPassword
        case unsupportedVersion(UInt8)
    }

    public static let formatVersion: UInt8 = 1
    public static let magic = Data("SDBK".utf8)
    /// Tur sayısı dosyada saklanır; ileride artırıldığında eski yedekler açılmaya devam eder.
    public static let defaultIterations: UInt32 = 600_000
    public static let minimumPasswordLength = 8
    static let saltLength = 32
    static let keyLength = 32

    public static func encrypt(_ plaintext: Data, password: String,
                               iterations: UInt32 = defaultIterations) throws -> Data {
        guard password.count >= minimumPasswordLength else { throw Failure.weakPassword }
        var salt = Data(count: saltLength)
        let status = salt.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, saltLength, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw Failure.keyDerivationFailed }

        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw Failure.keyDerivationFailed }

        var output = Data()
        output.append(magic)
        output.append(formatVersion)
        withUnsafeBytes(of: iterations.bigEndian) { output.append(contentsOf: $0) }
        output.append(salt)
        output.append(combined)
        return output
    }

    public static func decrypt(_ archive: Data, password: String) throws -> Data {
        let headerLength = magic.count + 1 + 4 + saltLength
        guard archive.count > headerLength,
              archive.prefix(magic.count) == magic else { throw Failure.corruptedArchive }

        var cursor = archive.startIndex + magic.count
        let version = archive[cursor]
        guard version == formatVersion else { throw Failure.unsupportedVersion(version) }
        cursor += 1

        let iterations = Data(archive[cursor..<(cursor + 4)])
            .withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
        cursor += 4

        let salt = Data(archive[cursor..<(cursor + saltLength)])
        cursor += saltLength

        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: Data(archive[cursor...]))
            return try AES.GCM.open(box, using: key)
        } catch {
            // Yanlış parola ile kurcalanmış dosya aynı hatayı verir; ayırt edilemez.
            throw Failure.wrongPassword
        }
    }

    static func deriveKey(password: String, salt: Data,
                          iterations: UInt32) throws -> SymmetricKey {
        let stretched = try pbkdf2(password: password, salt: salt, iterations: iterations)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: stretched),
            salt: salt,
            info: Data("sessizdefter.backup.v1".utf8),
            outputByteCount: keyLength)
    }

    static func pbkdf2(password: String, salt: Data, iterations: UInt32) throws -> Data {
        var output = Data(count: keyLength)
        let passwordBytes = Array(password.utf8)
        let status = output.withUnsafeMutableBytes { outputBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes, passwordBytes.count,
                    saltBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    outputBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), keyLength)
            }
        }
        guard status == kCCSuccess else { throw Failure.keyDerivationFailed }
        return output
    }
}
