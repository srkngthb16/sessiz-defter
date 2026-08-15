import Foundation

/// Ayarlar ekranındaki sürüm satırı ve geri bildirim metni aynı kaynaktan beslenir.
/// Bundle dışarıdan verilebiliyor: test paketinin kendi sürümü uygulamanınkiyle
/// karışmasın.
public struct AppVersion: Sendable, Equatable {
    public let marketing: String
    public let build: String

    public init(marketing: String, build: String) {
        self.marketing = marketing
        self.build = build
    }

    public init(bundle: Bundle = .main) {
        marketing = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "—"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    /// "1.0.0 (12)"
    public var displayString: String {
        build == "—" ? marketing : "\(marketing) (\(build))"
    }
}
