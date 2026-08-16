import Foundation

/// Anonim hata sayacı. Yalnızca "kaç kez" tutulur; hangi dosya, hangi işlem,
/// hangi tutar hiçbir yerde yazılmaz — geri bildirim metnine giren tek sayısal
/// bilgi bu olduğu için sayaç kişisel veri taşımamalı.
///
/// Hata metni de saklanmıyor: hata açıklamaları dosya adı ya da işyeri adı
/// içerebiliyor ve bu metin kullanıcının paylaştığı rapora sızardı.
/// `@unchecked Sendable`: tek saklama yeri UserDefaults, o da iş parçacığı
/// güvenli. Sayaç ekran modellerinin hata dallarından çağrılıyor, hepsini
/// MainActor'a bağlamak yazma yolunu gereksiz yere daraltırdı.
public struct Diagnostics: @unchecked Sendable {
    public enum Failure: String, CaseIterable, Sendable {
        case dataRead
        case statementImport
        case backup

        /// Geri bildirim metninde görünen ad.
        public var title: String {
            switch self {
            case .dataRead: "veri okuma"
            case .statementImport: "içe aktarma"
            case .backup: "yedekleme"
            }
        }

        var storageKey: String { "diagnostics.failure.\(rawValue)" }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record(_ failure: Failure) {
        defaults.set(count(failure) + 1, forKey: failure.storageKey)
    }

    public func count(_ failure: Failure) -> Int {
        defaults.integer(forKey: failure.storageKey)
    }

    public var total: Int {
        Failure.allCases.reduce(0) { $0 + count($1) }
    }

    /// Tüm verileri silmede sayaç da sıfırlanır: kullanıcı defteri sildikten
    /// sonra geri bildirimde eski hataları görmemeli.
    public func reset() {
        for failure in Failure.allCases { defaults.removeObject(forKey: failure.storageKey) }
    }
}
