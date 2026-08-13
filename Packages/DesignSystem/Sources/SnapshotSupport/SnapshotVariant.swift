import UIKit

/// Kritik ekranlar açık/koyu × standart/XXL olmak üzere 4 varyantta doğrulanır.
public struct SnapshotVariant: Sendable, Hashable {
    public let name: String
    public let style: UIUserInterfaceStyle
    public let sizeCategory: UIContentSizeCategory

    public init(name: String, style: UIUserInterfaceStyle, sizeCategory: UIContentSizeCategory) {
        self.name = name
        self.style = style
        self.sizeCategory = sizeCategory
    }

    public static let light = SnapshotVariant(name: "acik", style: .light, sizeCategory: .large)
    public static let dark = SnapshotVariant(name: "koyu", style: .dark, sizeCategory: .large)
    public static let lightXXL = SnapshotVariant(
        name: "acik-xxl", style: .light, sizeCategory: .accessibilityExtraExtraLarge)
    public static let darkXXL = SnapshotVariant(
        name: "koyu-xxl", style: .dark, sizeCategory: .accessibilityExtraExtraLarge)

    public static let dortVaryant: [SnapshotVariant] = [.light, .dark, .lightXXL, .darkXXL]
}

public enum SnapshotDevice {
    /// Tasarım panosunun referans boyutu.
    public static let iPhone15Pro = CGSize(width: 393, height: 852)
    public static let scale: CGFloat = 2
}
