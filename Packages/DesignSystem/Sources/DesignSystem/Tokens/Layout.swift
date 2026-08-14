import SwiftUI

public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 13
    public static let l: CGFloat = 18
    public static let xl: CGFloat = 24
}

public enum Radius {
    /// Tasarım kararları: canvas → kart (1px kenarlık, 16pt köşe) → sheet (22pt köşe).
    public static let card: CGFloat = 16
    public static let sheet: CGFloat = 22
    public static let control: CGFloat = 12
    public static let badge: CGFloat = 11
    public static let pill: CGFloat = 8
}

public enum Metrics {
    /// Her etkileşimli öğe en az 44×44 pt.
    public static let minimumTapTarget: CGFloat = 44
    /// Kategori rozeti (D1, D2 satırları).
    public static let badgeSize: CGFloat = 38
    /// Yön ikonu sabit konumda, 16 pt.
    public static let directionIconSize: CGFloat = 16
    public static let budgetBarHeight: CGFloat = 8
    public static let budgetBarHeightLarge: CGFloat = 12
}
