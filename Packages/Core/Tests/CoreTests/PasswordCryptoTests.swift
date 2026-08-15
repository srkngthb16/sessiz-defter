import Foundation
import Testing
@testable import Core

@Suite("Yedek şifreleme")
struct PasswordCryptoTests {
    /// Testler hızlı kalsın diye düşük tur sayısı; üretimde 600.000.
    static let testIterations: UInt32 = 1_000
    static let payload = Data("Sessiz Defter · 218 işlem".utf8)

    @Test("Şifrele ve çöz turu")
    func gidisDonus() throws {
        let archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        let opened = try PasswordCrypto.decrypt(archive, password: "dogru-parola")
        #expect(opened == Self.payload)
    }

    @Test("Aynı içerik iki kez şifrelenince farklı çıktı verir")
    func tuzFarki() throws {
        let first = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                               iterations: Self.testIterations)
        let second = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                iterations: Self.testIterations)
        #expect(first != second)
    }

    @Test("Yanlış parola çözmez")
    func yanlisParola() throws {
        let archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        #expect(throws: PasswordCrypto.Failure.wrongPassword) {
            try PasswordCrypto.decrypt(archive, password: "yanlis-parola")
        }
    }

    @Test("Tek bit kurcalama çözmeyi düşürür")
    func kurcalama() throws {
        var archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        archive[archive.count - 1] ^= 0x01
        #expect(throws: PasswordCrypto.Failure.wrongPassword) {
            try PasswordCrypto.decrypt(archive, password: "dogru-parola")
        }
    }

    @Test("Kısa parola reddedilir")
    func kisaParola() {
        #expect(throws: PasswordCrypto.Failure.weakPassword) {
            try PasswordCrypto.encrypt(Self.payload, password: "kisa",
                                       iterations: Self.testIterations)
        }
    }

    @Test("Başlık: imza, sürüm ve tur sayısı dosyada saklanır")
    func baslik() throws {
        let archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        #expect(archive.prefix(4) == PasswordCrypto.magic)
        #expect(archive[4] == PasswordCrypto.formatVersion)
        let iterations = Data(archive[5..<9])
            .withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(as: UInt32.self)) }
        #expect(iterations == Self.testIterations)
    }

    @Test("Bilinmeyen sürüm reddedilir")
    func sürüm() throws {
        var archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        archive[4] = 99
        #expect(throws: PasswordCrypto.Failure.unsupportedVersion(99)) {
            try PasswordCrypto.decrypt(archive, password: "dogru-parola")
        }
    }

    @Test("Bozuk dosya reddedilir")
    func bozukDosya() {
        #expect(throws: PasswordCrypto.Failure.corruptedArchive) {
            try PasswordCrypto.decrypt(Data("rastgele".utf8), password: "dogru-parola")
        }
    }

    @Test("Şifreli çıktıda düz metin görünmez")
    func duzMetinYok() throws {
        let archive = try PasswordCrypto.encrypt(Self.payload, password: "dogru-parola",
                                                 iterations: Self.testIterations)
        #expect(archive.range(of: Self.payload) == nil)
    }

    @Test("Aynı tuz ve tur sayısı aynı anahtarı verir")
    func anahtarBelirlenimi() throws {
        let salt = Data(repeating: 7, count: 32)
        let first = try PasswordCrypto.pbkdf2(password: "dogru-parola", salt: salt,
                                              iterations: Self.testIterations)
        let second = try PasswordCrypto.pbkdf2(password: "dogru-parola", salt: salt,
                                               iterations: Self.testIterations)
        #expect(first == second)
        #expect(first.count == 32)

        let other = try PasswordCrypto.pbkdf2(password: "baska-parola", salt: salt,
                                              iterations: Self.testIterations)
        #expect(first != other)
    }
}
