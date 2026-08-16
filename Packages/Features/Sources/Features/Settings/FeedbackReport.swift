import Foundation

/// Geri bildirim metni. Paylaşılan şey bu yapının ürettiği düz metnin tamamıdır;
/// ekranda gösterilen metinle gönderilen metin aynı olsun diye tek kaynak.
///
/// Kural: defterden yalnızca **sayı** çıkar. İşlem detayı, tutar, işyeri adı,
/// hesap adı, dosya adı ya da hata açıklaması bu metne giremez — kullanıcı
/// raporu tanımadığı birine gönderiyor olabilir.
public struct FeedbackReport: Equatable, Sendable {
    public let appVersion: String
    public let deviceModel: String
    public let systemVersion: String
    public let transactionCount: Int
    public let accountCount: Int
    public let budgetCount: Int
    /// (ad, sayı) — sıra sabit, sayaç sıfır olsa da yazılır ki eksik satır
    /// "gizlenmiş bilgi" izlenimi vermesin.
    public let failureCounts: [(name: String, count: Int)]
    public let note: String

    public init(
        appVersion: String,
        deviceModel: String,
        systemVersion: String,
        transactionCount: Int,
        accountCount: Int,
        budgetCount: Int,
        failureCounts: [(name: String, count: Int)],
        note: String = ""
    ) {
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.transactionCount = transactionCount
        self.accountCount = accountCount
        self.budgetCount = budgetCount
        self.failureCounts = failureCounts
        self.note = note
    }

    public static func == (lhs: FeedbackReport, rhs: FeedbackReport) -> Bool {
        lhs.text == rhs.text
    }

    public var text: String {
        var lines = [
            "Sessiz Defter — geri bildirim",
            "",
            "Uygulama sürümü: \(appVersion)",
            "Cihaz: \(deviceModel)",
            "iOS: \(systemVersion)",
            "",
            "Defter büyüklüğü (yalnızca sayı):",
            "· işlem: \(transactionCount)",
            "· hesap: \(accountCount)",
            "· bütçe: \(budgetCount)",
            "",
            "Hata sayacı:"
        ]
        for failure in failureCounts {
            lines.append("· \(failure.name): \(failure.count)")
        }
        lines += [
            "",
            "Bu metinde işlem detayı, tutar, işyeri adı, hesap bilgisi ya da dosya",
            "adı yoktur. Uygulama internete bağlanmaz; bu metni yalnızca siz,",
            "seçtiğiniz uygulamayla gönderirsiniz."
        ]
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            lines += ["", "Not:", trimmedNote]
        }
        return lines.joined(separator: "\n")
    }
}

/// Cihaz model kodu (`iPhone17,3`). Pazarlama adı yerine kod: eşleme tablosu
/// tutmak yeni model çıktığında "Bilinmeyen iPhone" yazmak demek, kod her zaman
/// doğru ve aynı bilgiyi taşıyor.
public enum DeviceModel {
    public static func identifier(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        // Simülatörde uname gerçek Mac'in mimarisini döner; simülatörün kendi
        // model kodu ortam değişkeninde.
        if let simulated = environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (simülatör)"
        }
        var info = utsname()
        uname(&info)
        let machine = info.machine
        return withUnsafeBytes(of: machine) { raw in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }
}
