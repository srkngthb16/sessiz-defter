import SwiftUI

// Tek giriş: her token açık/koyu çiftini kendi taşır.
extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    public enum bg {
        public static let canvas   = Color.dynamic(0xF6F8F8, 0x14191A)
        public static let surface  = Color.dynamic(0xFFFFFF, 0x1B2122)
        public static let elevated = Color.dynamic(0xFFFFFF, 0x222829)
        public static let subtle   = Color.dynamic(0xEDF1F0, 0x2A3132)
    }

    public enum border {
        public static let divider = Color.dynamic(0xE1E7E6, 0x2A3132)
        public static let `default` = Color.dynamic(0xCDD5D4, 0x38403F)
        public static let strong  = Color.dynamic(0xAEB9B8, 0x4B5453)
    }

    public enum text {
        public static let primary   = Color.dynamic(0x161D1C, 0xECF1F0) // 17.12 / 14.30
        public static let secondary = Color.dynamic(0x4E5958, 0xB3BDBC) //  7.26 /  8.48
        public static let muted     = Color.dynamic(0x687473, 0x8B9695) //  4.85 /  5.36
        public static let disabled  = Color.dynamic(0x8B9695, 0x6B7675)
        public static let onBrand   = Color.dynamic(0xFFFFFF, 0x06231F)
    }

    public enum brand {
        public static let primary = Color.dynamic(0x0A7C70, 0x3FCFBC)
        public static let surface = Color.dynamic(0xE2F2EF, 0x123A36)
    }

    public enum finance {
        public static let income   = Color.dynamic(0x0F7A43, 0x4FC98A)
        public static let expense  = Color.dynamic(0x9C4033, 0xE89A88)
        public static let transfer = Color.dynamic(0x4A6785, 0x93B4CE)
        public static let warning  = Color.dynamic(0x9A6100, 0xF2B33D)
        public static let critical = Color.dynamic(0xC21F14, 0xFF7A66)

        public static let incomeSurface   = Color.dynamic(0xE3F4EA, 0x123420)
        public static let expenseSurface  = Color.dynamic(0xF8E9E5, 0x3A1E18)
        public static let transferSurface = Color.dynamic(0xE9EFF5, 0x1C2A36)
        public static let warningSurface  = Color.dynamic(0xFAF0DC, 0x37290E)
        public static let criticalSurface = Color.dynamic(0xFBE4E1, 0x3D1A15)
    }

    public enum category {
        public static let all: [Color] = [
            .dynamic(0xB84A2E, 0xFFA88C), // 01 market
            .dynamic(0xE0A02A, 0xB07A1C), // 02 ulaşım
            .dynamic(0x5F6B12, 0xCBDA66), // 03 faturalar
            .dynamic(0x57B87A, 0x3E9E63), // 04 sağlık
            .dynamic(0x0E6E68, 0x5FDACB), // 05 abonelik
            .dynamic(0x57ADD6, 0x3C86B4), // 06 ev
            .dynamic(0x2A4FA8, 0x9DB6F7), // 07 eğitim
            .dynamic(0x9A8CE8, 0x7A68CC), // 08 eğlence
            .dynamic(0x6D2E96, 0xD9A3F0), // 09 alışveriş
            .dynamic(0xE884BC, 0xC2568E), // 10 kişisel bakım
            .dynamic(0xA32348, 0xF79CB2), // 11 bağış
            .dynamic(0x92A0A9, 0x7B8A93)  // 12 diğer
        ]
    }

    public enum chart {
        public static let sequential: [Color] = [
            .dynamic(0xD7EEEB, 0x10352F),
            .dynamic(0xA9DCD6, 0x164F47),
            .dynamic(0x74C6BE, 0x1E7369),
            .dynamic(0x3FA99F, 0x2F9C8E),
            .dynamic(0x0A7C70, 0x4EC5B4),
            .dynamic(0x05564D, 0x86E2D5)
        ]
        // Karşılaştırmalı skala: komşu ayrımı en yüksek sıra
        public static let categorical: [Color] = [4, 1, 6, 9, 2, 5, 8, 11]
            .map { Color.category.all[$0] }
    }
}

extension UIColor {
    public convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1)
    }
}
