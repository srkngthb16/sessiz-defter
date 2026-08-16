import Core
import Domain
import Foundation

/// Ekran kartlarının ve grafiklerin VoiceOver karşılıkları.
///
/// Kartlar görsel olarak birden çok metinden oluşuyor; her parçayı ayrı ayrı
/// okumak kullanıcıyı rakam yığınında bırakıyor. Cümleler burada kuruluyor ki
/// görünümler ince kalsın ve okunuş test edilebilsin.
enum SpokenSummary {
    /// "Toplam net varlık 47.709 lira 67 kuruş, bu ay artı 25.312 lira 7 kuruş, 1 hesap"
    static func netWorth(_ netWorth: Money, monthNet: Money, accountCount: Int) -> String {
        let month = Fmt.spoken(monthNet.magnitude,
                               sign: monthNet.isNegative ? .expense : .income)
        return "Toplam net varlık \(Fmt.spoken(netWorth)), bu ay \(month), "
            + "\(accountCount) hesap"
    }

    /// "Gelir artı 48.500 lira"
    static func summaryTile(_ title: String, _ amount: Money, isIncome: Bool) -> String {
        "\(title) \(Fmt.spoken(amount, sign: isIncome ? .income : .expense))"
    }

    /// "Ulaşım bütçesi aşıldı, yüzde 114, harcanan 1.600 lira, limit 1.400 lira,
    /// 200 lira aşıldı"
    static func budget(_ status: BudgetStatus, categoryName: String) -> String {
        var parts = ["\(categoryName) bütçesi \(status.state.label.lowercased())",
                     Fmt.spokenPercent(status.ratio),
                     "harcanan \(Fmt.spoken(status.spent, sign: .none))",
                     "limit \(Fmt.spoken(status.effectiveLimit, sign: .none))"]
        if let overspend = status.overspend {
            parts.append("\(Fmt.spoken(overspend, sign: .none)) aşıldı")
        } else {
            parts.append("kalan \(Fmt.spoken(status.remaining, sign: .none))")
        }
        return parts.joined(separator: ", ")
    }

    /// "Ev 18.000 lira, yüzde 78"
    static func breakdownRow(name: String, amount: Money, share: Double) -> String {
        "\(name) \(Fmt.spoken(amount, sign: .none)), \(Fmt.spokenPercent(share))"
    }

    /// Grafiğin sözlü özeti: en yüksek ve en düşük gider dönemi ile son dönem.
    /// Çubukları tek tek dinlemek eğilimi anlatmıyor; özet önce söylenir.
    static func trend(points: [(label: String, income: Money, expense: Money)]) -> String {
        guard let last = points.last,
              let highest = points.max(by: { $0.expense < $1.expense }),
              let lowest = points.min(by: { $0.expense < $1.expense }) else {
            return "Grafikte veri yok"
        }
        return "\(points.count) dönem. "
            + "En yüksek gider \(highest.label), \(Fmt.spoken(highest.expense, sign: .none)). "
            + "En düşük gider \(lowest.label), \(Fmt.spoken(lowest.expense, sign: .none)). "
            + "Son dönem \(last.label), gelir \(Fmt.spoken(last.income, sign: .none)), "
            + "gider \(Fmt.spoken(last.expense, sign: .none))."
    }
}
