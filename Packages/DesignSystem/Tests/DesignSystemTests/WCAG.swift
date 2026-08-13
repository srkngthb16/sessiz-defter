import SwiftUI
import UIKit

enum WCAG {
    static func relativeLuminance(_ color: UIColor, style: UIUserInterfaceStyle) -> Double {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    static func contrastRatio(_ lhs: Color, _ rhs: Color, style: UIUserInterfaceStyle) -> Double {
        let a = relativeLuminance(UIColor(lhs), style: style)
        let b = relativeLuminance(UIColor(rhs), style: style)
        let hi = max(a, b), lo = min(a, b)
        return (hi + 0.05) / (lo + 0.05)
    }
}
