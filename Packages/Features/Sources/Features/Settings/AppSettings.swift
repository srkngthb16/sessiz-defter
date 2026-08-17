import Foundation

/// Tercihler UserDefaults'ta: hassas veri değil, hepsi kullanıcının kendi ayarı.
/// Hassas alan anahtarları Keychain'de tutulur (Core/Keychain).
@Observable
@MainActor
public final class AppSettings {
    public enum AutoLockDelay: Int, CaseIterable, Identifiable, Sendable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300

        public var id: Int { rawValue }

        public var title: String {
            switch self {
            case .immediately: "Hemen"
            case .oneMinute: "1 dk"
            case .fiveMinutes: "5 dk"
            }
        }
    }

    public enum Appearance: String, CaseIterable, Identifiable, Sendable {
        case system, light, dark

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .system: "Sistem"
            case .light: "Açık"
            case .dark: "Koyu"
            }
        }
    }

    /// Arayüz dili. "Sistem" cihaz dilini kullanır, diğerleri onu geçersiz kılar —
    /// yurt dışında yaşayan kullanıcı cihazı İngilizceyken uygulamayı Türkçe
    /// tutabilsin diye. Seçim metinleri ve sayı biçimini etkiler; tutarların para
    /// birimi hesabın kendi biriminden gelir, dile bağlı değildir.
    public enum Language: String, CaseIterable, Identifiable, Sendable {
        case system, turkish, english

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .system: "Sistem"
            case .turkish: "Türkçe"
            case .english: "English"
            }
        }

        /// nil = cihazın kendi dili.
        public var locale: Locale? {
            switch self {
            case .system: nil
            case .turkish: Locale(identifier: "tr_TR")
            case .english: Locale(identifier: "en_US")
            }
        }
    }

    private enum Key {
        static let lockEnabled = "lock.enabled"
        static let hideInSwitcher = "lock.hideInSwitcher"
        static let autoLockDelay = "lock.autoLockDelay"
        static let appearance = "appearance"
        static let onboardingCompleted = "onboarding.completed"
        static let tourSeen = "tour.seen"
        static let language = "language"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isLockEnabled = defaults.bool(forKey: Key.lockEnabled)
        hidesContentInSwitcher = defaults.object(forKey: Key.hideInSwitcher) as? Bool ?? true
        // integer(forKey:) anahtar yoksa 0 döner ve 0 "Hemen" demek; varsayılan
        // 1 dk olmalı, bu yüzden yokluk object(forKey:) ile ayırt edilir.
        autoLockDelay = (defaults.object(forKey: Key.autoLockDelay) as? Int)
            .flatMap(AutoLockDelay.init(rawValue:)) ?? .oneMinute
        appearance = Appearance(rawValue: defaults.string(forKey: Key.appearance) ?? "")
            ?? .system
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboardingCompleted)
        hasSeenTour = defaults.bool(forKey: Key.tourSeen)
        language = Language(rawValue: defaults.string(forKey: Key.language) ?? "")
            ?? .system
    }

    public var isLockEnabled: Bool {
        didSet { defaults.set(isLockEnabled, forKey: Key.lockEnabled) }
    }

    /// Uygulama arka plana alındığında ekranı bulanıklaştır — App Switcher'da
    /// bakiye görünmemeli.
    public var hidesContentInSwitcher: Bool {
        didSet { defaults.set(hidesContentInSwitcher, forKey: Key.hideInSwitcher) }
    }

    public var autoLockDelay: AutoLockDelay {
        didSet { defaults.set(autoLockDelay.rawValue, forKey: Key.autoLockDelay) }
    }

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboardingCompleted) }
    }

    /// İlk kullanım turu bir kez gösterilir. Onboarding'den ayrı bir bayrak:
    /// onboarding neyin olmadığını anlatıyor, tur ekranın neresine dokunulacağını.
    /// Aynı bayrağa bağlanırsa mevcut kullanıcılar güncellemede turu hiç görmezdi.
    public var hasSeenTour: Bool {
        didSet { defaults.set(hasSeenTour, forKey: Key.tourSeen) }
    }

    public var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    public var colorScheme: ColorSchemePreference {
        switch appearance {
        case .system: .system
        case .light: .light
        case .dark: .dark
        }
    }
}

public enum ColorSchemePreference: Sendable {
    case system, light, dark
}
