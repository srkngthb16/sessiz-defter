import Core
import SwiftUI

/// Tutar gösteriminin tek kapısı.
///
/// Kurallar tasarım dosyasından:
/// - Sıradan gider tutarı `text.primary`'dir, kırmızı DEĞİL. Kırmızı yalnızca anormal
///   durum (bütçe aşımı) için ayrılmıştır.
/// - Ayrım renge emanet edilmez: işaret her zaman yazılır.
/// - `accessibilityDifferentiateWithoutColor` açıkken tutar nötr renge düşer ve ayrım
///   kalın işaretle taşınır.
/// - Tüm tutarlar tabular figür ve sağa dayalı.
public struct AmountText: View {
    public enum Style {
        /// Dashboard bakiyesi: 44 pt, .accessibility2'de 56 pt'ta durur, asla sarmaz.
        case hero
        /// İşlem satırı tutarı.
        case row
        /// Özet kartlarındaki gelir/gider rakamı.
        case summary
    }

    let amount: Money
    let direction: TransactionDirectionStyle
    let style: Style
    /// Bütçe aşımı gibi anormal durum. Yalnızca burada kırmızı kullanılır.
    let isCritical: Bool
    /// Bakiye gibi yönsüz tutarlarda işaret yazılmaz.
    let showsSign: Bool

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var systemDifferentiateWithoutColor
    @Environment(\.differentiateWithoutColorOverride) private var differentiateOverride
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var differentiateWithoutColor: Bool {
        differentiateOverride ?? systemDifferentiateWithoutColor
    }

    public init(
        amount: Money,
        direction: TransactionDirectionStyle,
        style: Style = .row,
        isCritical: Bool = false,
        showsSign: Bool = true
    ) {
        self.amount = amount
        self.direction = direction
        self.style = style
        self.isCritical = isCritical
        self.showsSign = showsSign
    }

    public var body: some View {
        content
            .foregroundStyle(color)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .hero:
            Text(text)
                .font(.custom(TypeFace.data, size: Self.heroSize(for: dynamicTypeSize),
                              relativeTo: .largeTitle))
                .fontWeight(.medium)
                .monospacedDigit()
                .kerning(-0.02 * Self.heroSize(for: dynamicTypeSize))
                // Punto kendi tablosuyla ölçekleniyor; Dynamic Type ikinci kez
                // büyütmesin diye ölçek burada sabitlenir.
                .dynamicTypeSize(.large)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .row:
            Text(attributedText)
                .font(.sd.amountRow)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .summary:
            Text(attributedText)
                .font(.custom(TypeFace.data, size: 17, relativeTo: .body))
                .fontWeight(.medium)
                .monospacedDigit()
                .lineLimit(1)
                // Tutar sarmaz; dar alanda kırpmak yerine küçülür.
                .minimumScaleFactor(0.8)
        }
    }

    private var signPrefix: String {
        // Yönsüz tutarda (bakiye) işaret yönden değil değerin kendisinden gelir:
        // eksi bakiyeyi mutlak değerle göstermek yanlış rakam gösterir.
        if direction == .neutral { return amount.isNegative ? "\u{2212}" : "" }
        guard showsSign else { return "" }
        return direction.signPrefix
    }

    /// Test görünürlüğü: işaret mantığı gösterimin en kritik parçası.
    var debugSignPrefix: String { signPrefix }

    private var text: String {
        signPrefix + Fmt.currency(amount)
    }

    /// Renk kapalıyken ayrım işaretin kalınlığına biner.
    private var attributedText: AttributedString {
        var result = AttributedString(signPrefix)
        if differentiateWithoutColor, !signPrefix.isEmpty {
            result.font = .custom(TypeFace.data, size: 16, relativeTo: .body).weight(.bold)
        }
        result.append(AttributedString(Fmt.currency(amount)))
        return result
    }

    private var color: Color {
        if differentiateWithoutColor { return .text.primary }
        if isCritical { return .finance.critical }
        switch direction {
        case .income: return .finance.income
        // Gider kırmızı değil: her harcama alarm gibi görünmemeli.
        case .expense, .transfer, .neutral: return .text.primary
        }
    }

    private var accessibilityLabel: String {
        let prefix = switch direction {
        case .income: "gelir"
        case .expense: "gider"
        case .transfer: "transfer"
        case .neutral: ""
        }
        let critical = isCritical ? ", bütçe aşıldı" : ""
        return "\(prefix) \(Fmt.currency(amount))\(critical)"
            .trimmingCharacters(in: .whitespaces)
    }

    /// 44 pt tabandan başlar, .accessibility2'de 56 pt'ta durur; ötesinde punto sabit
    /// kalır ve minimumScaleFactor devreye girer — bakiye asla kırpılmaz, asla sarmaz.
    /// Aradaki kademeler tasarımda verilmedi, iki uç arasında düzgün dağıtıldı.
    static func heroSize(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: 40
        case .small: 41
        case .medium: 42
        case .large: 44
        case .xLarge: 46
        case .xxLarge: 48
        case .xxxLarge: 50
        case .accessibility1: 53
        default: 56
        }
    }
}

/// DesignSystem Domain'e bağımlı değil; yön bilgisi bu küçük tiple taşınır.
public enum TransactionDirectionStyle: String, Sendable, CaseIterable {
    case income
    case expense
    case transfer
    /// Bakiye gibi yönsüz tutarlar.
    case neutral

    public var signPrefix: String {
        switch self {
        case .income: "+"
        case .expense: "\u{2212}"
        case .transfer, .neutral: ""
        }
    }

    public var symbolName: String? {
        switch self {
        case .income: "arrow.down.left"
        case .expense: "arrow.up.right"
        case .transfer: "arrow.left.arrow.right"
        case .neutral: nil
        }
    }

    public var tint: Color {
        switch self {
        case .income: .finance.income
        case .expense: .finance.expense
        case .transfer: .finance.transfer
        case .neutral: .text.muted
        }
    }

    public var surface: Color {
        switch self {
        case .income: .finance.incomeSurface
        case .expense: .finance.expenseSurface
        case .transfer: .finance.transferSurface
        case .neutral: .bg.subtle
        }
    }
}
