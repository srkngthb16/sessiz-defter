import Core
import Foundation

public struct CategorySuggestion: Hashable, Sendable {
    public let categoryID: UUID?
    /// 0...1. Eşik altındaki her satır onay ekranında işaretli gelir.
    public let confidence: Double
    public let matchedKeyword: String?

    public init(categoryID: UUID?, confidence: Double, matchedKeyword: String? = nil) {
        self.categoryID = categoryID
        self.confidence = confidence
        self.matchedKeyword = matchedKeyword
    }

    public static let none = CategorySuggestion(categoryID: nil, confidence: 0)
}

/// Kural tabanlı kategorileme. Karşılaştırma Türkçe harfler ASCII'ye katlanarak
/// yapılır: ekstre "ATASEHIR", kullanıcı kuralı "Ataşehir" yazar.
public struct CategorizationEngine: Sendable {
    /// Bu eşiğin altındaki öneriler kullanıcı onayına düşer (C3 "kontrol gerekiyor").
    public static let reviewThreshold = 0.7

    let rules: [CategoryRuleEntity]

    public init(rules: [CategoryRuleEntity]) {
        self.rules = rules
    }

    public func suggest(detail: String, direction: TransactionDirection) -> CategorySuggestion {
        let haystack = Self.fold(detail)
        var best: (rule: CategoryRuleEntity, score: Double)?

        for rule in rules {
            let needle = Self.fold(rule.keyword)
            guard !needle.isEmpty, haystack.contains(needle) else { continue }
            if let required = rule.direction, required != direction { continue }

            // Uzun anahtar daha spesifiktir; tam kelime eşleşmesi ek güven verir.
            var score = min(0.6 + Double(needle.count) / 40, 0.95)
            if Self.matchesWholeWord(needle, in: haystack) { score = min(score + 0.1, 0.98) }
            if rule.isUserDefined { score = min(score + 0.05, 0.99) }

            if best == nil || score > best!.score { best = (rule, score) }
        }

        guard let best else { return .none }
        return CategorySuggestion(categoryID: best.rule.categoryID,
                                  confidence: best.score,
                                  matchedKeyword: best.rule.keyword)
    }

    static func fold(_ text: String) -> String {
        let mapping: [Character: Character] = [
            "İ": "I", "I": "I", "ı": "I", "i": "I",
            "Ş": "S", "ş": "S", "Ğ": "G", "ğ": "G",
            "Ç": "C", "ç": "C", "Ö": "O", "ö": "O", "Ü": "U", "ü": "U"
        ]
        return String(text.map { mapping[$0] ?? $0 })
            .uppercased(with: Locale(identifier: "en_US"))
    }

    static func matchesWholeWord(_ needle: String, in haystack: String) -> Bool {
        haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { $0 == needle }
    }
}

/// İlk açılışta yazılan kurallar. Kullanıcı bunları silebilir ya da üzerine yazabilir.
public enum DefaultCategoryRules {
    public static func seed(categories: [CategoryEntity]) -> [CategoryRuleEntity] {
        let byName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0.id) })
        // Marka adlarının yanında **cins adlar** da var. Gerçek ekstrelerde
        // (kullanıcı 2026-08-17'de dört PDF verdi) işyeri adları markadan çok
        // "KARDEŞLER MARKET", "ÇAĞDAŞ MARKET", "TOPLU TASIMA UCRETI" gibi geliyor;
        // yalnız markaya bakan liste bunların hepsini kategorisiz bırakıyordu.
        let pairs: [(String, String)] = [
            ("MIGROS", "Market"), ("BIM", "Market"), ("A101", "Market"),
            ("CARREFOUR", "Market"), ("SOK MARKET", "Market"), ("MARKET", "Market"),
            ("BAKKAL", "Market"), ("MANAV", "Market"), ("KASAP", "Market"),
            ("GIDA", "Market"), ("SUPERMARKET", "Market"), ("FIRIN", "Market"),

            ("SHELL", "Ulaşım"), ("OPET", "Ulaşım"), ("BP ", "Ulaşım"),
            ("PETROL", "Ulaşım"), ("AKARYAKIT", "Ulaşım"), ("BENZIN", "Ulaşım"),
            ("IETT", "Ulaşım"), ("OTOYOL", "Ulaşım"), ("TAKSI", "Ulaşım"),
            ("TOPLU TASIMA", "Ulaşım"), ("OTOPARK", "Ulaşım"), ("HGS", "Ulaşım"),
            ("OGS", "Ulaşım"), ("BILET", "Ulaşım"),

            ("ISKI", "Faturalar"), ("BEDAS", "Faturalar"), ("IGDAS", "Faturalar"),
            ("TURKCELL", "Faturalar"), ("VODAFONE", "Faturalar"), ("FATURA", "Faturalar"),
            ("TURK TELEKOM", "Faturalar"), ("DOGALGAZ", "Faturalar"),
            ("ELEKTRIK", "Faturalar"), ("INTERNET", "Faturalar"),

            ("ECZANE", "Sağlık"), ("HASTANE", "Sağlık"), ("DIS ", "Sağlık"),
            ("KLINIK", "Sağlık"), ("LABORATUVAR", "Sağlık"), ("OPTIK", "Sağlık"),

            ("SPOTIFY", "Abonelik"), ("NETFLIX", "Abonelik"), ("ICLOUD", "Abonelik"),
            ("YOUTUBE", "Abonelik"), ("ABONELIK", "Abonelik"), ("APPLE COM", "Abonelik"),

            ("KIRA", "Ev"), ("AIDAT", "Ev"), ("EMLAK", "Ev"), ("MOBILYA", "Ev"),

            ("TRENDYOL", "Alışveriş"), ("HEPSIBURADA", "Alışveriş"), ("AMAZON", "Alışveriş"),
            ("ALISVERIS", "Alışveriş"), ("MAGAZA", "Alışveriş"), ("TEKSTIL", "Alışveriş"),
            ("BOYNER", "Alışveriş"), ("LC WAIKIKI", "Alışveriş"), ("DEFACTO", "Alışveriş"),
            ("FLO", "Alışveriş"), ("ILETISIM", "Alışveriş"),

            ("KAHVE", "Yeme-içme"), ("RESTORAN", "Yeme-içme"), ("YEMEKSEPETI", "Yeme-içme"),
            ("GETIR", "Yeme-içme"), ("LOKANTA", "Yeme-içme"), ("PIDE", "Yeme-içme"),
            ("KEBAP", "Yeme-içme"), ("CAFE", "Yeme-içme"), ("PASTANE", "Yeme-içme"),
            ("BUFE", "Yeme-içme"), ("TEKEL", "Yeme-içme"),

            ("KUAFOR", "Kişisel bakım"), ("BERBER", "Kişisel bakım"),
            ("KOZMETIK", "Kişisel bakım"), ("GRATIS", "Kişisel bakım"),

            ("OKUL", "Eğitim"), ("KURS", "Eğitim"), ("UNIVERSITE", "Eğitim"),
            ("KITAP", "Eğitim"),

            ("SINEMA", "Eğlence"), ("TIYATRO", "Eğlence"), ("ORGANIZASYON", "Eğlence"),
            ("KONSER", "Eğlence"),

            // Banka işlemleri: kart ödemesi, havale, faiz ve ücretler. Harcama
            // kategorisi değiller ama "Diğer" olarak işaretlenmeleri kategorisiz
            // yığınında kalmalarından iyi — kullanıcı isterse değiştirir.
            ("KREDI KART ODEME", "Diğer"), ("K.KARTI ODEME", "Diğer"),
            ("KART ODEME", "Diğer"), ("HESAPLAR ARASI TRANSFER", "Diğer"),
            ("GIDEN FAST", "Diğer"), ("PARA TRANSFERI", "Diğer"), ("HAVALE", "Diğer"),
            ("NAKIT AVANS", "Diğer"), ("PARA CEKME", "Diğer"),
            ("KESINTI VE EKLERI", "Diğer"), ("KKDF", "Diğer"), ("BSMV", "Diğer"),
            ("FAIZ", "Diğer"), ("KOMISYON", "Diğer")
        ]
        var rules = pairs.compactMap { keyword, categoryName -> CategoryRuleEntity? in
            guard let categoryID = byName[categoryName] else { return nil }
            return CategoryRuleEntity(keyword: keyword, categoryID: categoryID,
                                      direction: .expense, isUserDefined: false)
        }
        if let maas = byName["Maaş"] {
            rules.append(CategoryRuleEntity(keyword: "MAAS", categoryID: maas,
                                            direction: .income, isUserDefined: false))
        }
        return rules
    }
}
