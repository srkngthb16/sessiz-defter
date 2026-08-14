import SwiftUI

/// SwiftUI'ın `accessibilityDifferentiateWithoutColor` ortam değeri salt okunur;
/// snapshot testinde açık hâli doğrulanamıyor. Bileşenler bu köprüden okur:
/// üretimde sistem ayarı geçerli, testte override verilir.
private struct DifferentiateWithoutColorOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    public var differentiateWithoutColorOverride: Bool? {
        get { self[DifferentiateWithoutColorOverrideKey.self] }
        set { self[DifferentiateWithoutColorOverrideKey.self] = newValue }
    }
}

struct DifferentiateWithoutColorReader<Content: View>: View {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemValue
    @Environment(\.differentiateWithoutColorOverride) private var override

    let content: (Bool) -> Content

    var body: some View {
        content(override ?? systemValue)
    }
}
