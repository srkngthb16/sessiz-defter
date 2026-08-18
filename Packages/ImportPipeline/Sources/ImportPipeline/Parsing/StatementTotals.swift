import Core
import Domain
import Foundation

/// Ekstrenin kendi yazdığı toplamlar. Onay ekranında okunan toplamla yan yana
/// gösteriliyorlar.
///
/// Neden: ayrıştırıcı yanlış okuduğunda bunu ne ben ne de kullanıcı fark
/// edebiliyordu — cihaz testinde ekstre 2.529,15 TL borç yazarken uygulama
/// 37.289,15 TL gösterdi ve fark yalnız kullanıcı ekstreyi elle kontrol edince
/// ortaya çıktı. Ekstre kendi toplamını zaten yazıyor; iki sayıyı yan yana
/// koymak, benim göremediğim her hatayı kullanıcıya görünür kılıyor.
///
/// Bilerek "doğrula ve reddet" değil "göster": hangi toplamın hangi satır
/// kümesine karşılık geldiği bankadan bankaya değişiyor (kimi faizi katıyor,
/// kimi katmıyor). Otomatik karşılaştırma yanlış alarm üretirdi; kullanıcının
/// gözü üretmiyor.
public enum StatementTotals {
    public struct Declared: Hashable, Sendable, Identifiable {
        public let label: String
        public let amount: Money
        public var id: String { label }
    }

    /// Toplam satırlarını işaretleyen ifadeler. Hepsi ekstrelerde birebir geçiyor.
    private static let labels = [
        "DONEM ICI BORC", "DONEM BORCUNUZ", "TOPLAM BORC", "TOPLAM ALACAK",
        "HESAP BAKIYESI", "TOPLAM", "ASGARI ODEME", "MIN. ODEME"
    ]

    public static func declared(in text: String, limit: Int = 4) -> [Declared] {
        var found: [Declared] = []
        var seen = Set<String>()

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = TextNormalizer.collapseSpaces(
                String(rawLine).trimmingCharacters(in: .whitespaces))
            guard !line.isEmpty else { continue }
            let folded = TextNormalizer.fold(line)
            guard let label = labels.first(where: folded.contains) else { continue }

            // Satırdaki son kuruşlu sayı toplamdır; öncesindekiler tarih ya da
            // limit gibi başka alanlar olabiliyor.
            let money = line.split(separator: " ").map(String.init)
                .last { token in
                    guard let parsed = AmountParser.parse(token), parsed.amount.minorUnits > 0
                    else { return false }
                    return token.contains(",") || token.contains(".")
                }
            guard let money, let parsed = AmountParser.parse(money) else { continue }

            // Aynı toplam ekstrede birkaç kez yazılıyor (üst özet ve alt özet).
            let title = readableLabel(for: label)
            guard seen.insert(title).inserted else { continue }
            found.append(Declared(amount: parsed.amount, label: title))
            if found.count == limit { break }
        }
        return found
    }

    private static func readableLabel(for folded: String) -> String {
        switch folded {
        case "DONEM ICI BORC": "Dönem içi borç"
        case "DONEM BORCUNUZ": "Dönem borcu"
        case "TOPLAM BORC": "Toplam borç"
        case "TOPLAM ALACAK": "Toplam alacak"
        case "HESAP BAKIYESI": "Hesap bakiyesi"
        case "ASGARI ODEME", "MIN. ODEME": "Asgari ödeme"
        default: "Toplam"
        }
    }
}

extension StatementTotals.Declared {
    public init(amount: Money, label: String) {
        self.init(label: label, amount: amount)
    }
}
